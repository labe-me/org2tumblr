//
// Manage a blog from an org file.
//
// Requirements: googlecl, tumblr-rb
//
// sudo gem install tumblr-rb
// http://mwunsch.github.com/tumblr/tumblr.5.html
//
// Author: Laurent Bedubourg <laurent@labe.me>
//

import Org;
import Picasync.Cache;

class Text {
    public static function orgToHtml(str:String) : String {
        if (str == null)
            return null;

        // org links to images embeds images in markdown
        var reg = ~/(\[\[(.*?\.(jpg|png|gif))\]\])/g;
        str = reg.customReplace(str, function(r){
            return "![]("+r.matched(2)+")";
        });

        // [[link]]
        var reg = ~/(\[\[([^\]]+)\]\])/g;
        str = reg.customReplace(str, function(r){
            return "["+reg.matched(2)+"]("+reg.matched(2)+")";
        });

        // [[link][text]]
        var reg = ~/(\[\[(.*?)\]\[(.*?)\]\])/g;
        str = reg.customReplace(str, function(r){
            return "["+reg.matched(3)+"]("+reg.matched(2)+")";
        });

        // examples
        var reg = ~/(#\+BEGIN_EXAMPLE.*?#\+END_EXAMPLE)/gs;
        str = reg.customReplace(str, function(r){
            var s = r.matched(1);
            s = StringTools.replace(s, "#+BEGIN_EXAMPLE", "");
            s = StringTools.replace(s, "#+END_EXAMPLE", "");
            s = StringTools.replace(s, "\n", "\n    ");
            return s;
        });

        var result = Markdown.run(str);

        // trim spaces between around link images
        var reg = ~/(<a [^<>]+>)\s+(<img [^<>]+>)\s+(<\/a>)/gs;
        result = reg.customReplace(result, function(r){
            return r.matched(1)+reg.matched(2)+reg.matched(3);
        });

        return result;
    }

    public static function htmlLocal(html:String){
        var reg = ~/"(file:)?(\.\/)?picasa\/(.*?)"/g;
        html = reg.customReplace(html, function(r){
            return "\"../picasa/"+r.matched(3)+"\"";
        });

        var reg = ~/"(file:)?(\.\/)?www\/(.*?)"/g;
        html = reg.customReplace(html, function(r){
            return "\"../www/"+r.matched(3)+"\"";
        });

        return html;
    }

    public static function htmlFinal(html:String, staticUrl:String){
        var picasync = haxe.Unserializer.run(neko.io.File.getContent("./picasa/.picasync"));

        var reg = ~/"(file:)?(\.\/)?picasa\/(.*?)"/g;
        html = reg.customReplace(html, function(r){
            var pic = picasync.get(r.matched(3));
            if (pic == null){
                throw "ERROR: file not found in picasa cache: '"+r.matched(3)+"', picasa might not be synchronized with your new content yet?";
            }
            return "\""+picasync.get(r.matched(3)).url+"\"";
        });

        if (staticUrl != null){
            var reg = ~/"(file:)?(\.\/)?www\/(.*?)"/g;
            html = reg.customReplace(html, function(r){
                return "\""+staticUrl+"/"+r.matched(3)+"\"";
            });
        }

        return html;
    }
}

class TumblrId {

    public static var POST_ID_KEY = "POST-ID";

    static function createId(id:String){
        return ":"+POST_ID_KEY+": "+id+"\n";
    }

    static function createDrawer(id:String){
        return ":PROPERTIES:\n" + createId(id) + ":END:\n";
    }

    static function insert(str:String, pos:Int, what:String){
        return str.substr(0, pos) + what + str.substr(pos);
    }

    public static function getId(node:OrgNode){
        return node.properties.get(POST_ID_KEY);
    }

    /*
      Insert tumblr post-id to node properties.

      Returns: the org file source modified accordingly.
     */
    public static function addPostIdToOrgNode(str:String, node:OrgNode, id:String){
        var oldId = node.properties.get(POST_ID_KEY);
        if (id == null || oldId == id)
            return str;
        if (oldId != null && id != null && oldId != id){
            str = StringTools.replace(str, ":"+POST_ID_KEY+": "+oldId+"\n", ":"+POST_ID_KEY+": "+id+"\n");
            return str;
        }
        node.properties.set(POST_ID_KEY, id);
        var posT = str.indexOf(node.title);
        if (posT == -1)
            throw "Org node not found";
        var posE = str.indexOf("\n", posT);
        var posSP = str.indexOf(":PROPERTIES:", posE);
        if (posSP == -1)
            return insert(str, posE+1, createDrawer(id));
        var sub = str.substr(posE, posSP-posE);
        if (~/^\*+ /s.match(sub))
            return insert(str, posE+1, createDrawer(id));
        var posEP = str.indexOf(":END:", posSP);
        if (posEP == -1)
            throw "Malformed org file";
        return insert(str, posEP, createId(id));
    }
}

class App {

    static var TMP_FILE = "/tmp/tumblr.tmp";

    public static function postOrgNode(root:OrgNode, node:OrgNode, cred:String, staticUrl:String){
        var id = TumblrId.getId(node);
        if (node.text == null || node.state == null){
            neko.Lib.println("Ignoring \""+node.title+"\"");
            return id;
        }
        var buf = new StringBuf();
        var yaml = function(k,v){
            buf.add(k);
            buf.add(": ");
            buf.add(v);
            buf.add("\n");
        }
        buf.add("---\n");
        yaml("title", '"'+StringTools.replace(node.title, '"', "\\\"") + '"');
        yaml("email", root.properties.get("EMAIL"));
        yaml("group", root.properties.get("BLOG"));
        yaml("tags", node.tags.join(", "));
        yaml("format", "html");
        if (id != null)
            yaml("post-id", id);
        yaml("state", /* draft, queu, submission, published */
        switch (node.state){
            case "TODO": "draft";
            case "DONE": "published";
            default: "draft";
        });
        var date = node.properties.get("HEAD_DATE");
        if (date == null)
            date = node.properties.get("CLOSED");
        if (date == null)
            date = node.properties.get("TEXT_DATE");
        if (date == null)
            date = node.properties.get("DATE");
        if (date != null){
            var r = ~/^[<\[](.*?)[>\]]$/;
            if (r.match(date))
                date = r.matched(1);
            var r = ~/^(\d{4}-\d{2}-\d{2}) [a-zA-Z]{3}( \d\d:\d\d)?$/;
            if (r.match(date))
                date = r.matched(1)+(r.matched(2) != null ? (r.matched(2)+":00") : "");
            var dt = Date.fromString(date);
            yaml("date", dt.toString());
        }
        buf.add("---\n\n");
        buf.add(Text.htmlFinal(Text.orgToHtml(node.text), staticUrl));
        var out = neko.io.File.write(TMP_FILE,true);
        out.writeString(buf.toString());
        out.close();
        id = Tumblr.post(TMP_FILE, cred);
        neko.Lib.println("Synchronizing \""+node.title+"\"");
        neko.FileSystem.deleteFile(TMP_FILE);
        return id;
    }

    static function optMatch(arg:String, reg:EReg, cb:EReg->Void){
        if (reg.match(arg)){
            cb(reg);
            return true;
        }
        return false;
    }

    public static function main(){
        var argv = neko.Sys.args();
        var file = null;
        var action = null;
        var options = new Hash();
        var credfile = null;
        var staticUrl = null;
        var reverse = false;
        while (argv.length > 0){
            var arg = argv.shift();
            if (optMatch(arg, ~/^--credentials=(.*?)$/, function(r) credfile=r.matched(1)))
                continue;
            if (optMatch(arg, ~/^--www=(.*?)$/, function(r) staticUrl=r.matched(1)))
                continue;
            if (optMatch(arg, ~/^--reverse$/, function(r) reverse = true))
                continue;
            switch (arg){
                case "picasa": action = arg;
                case "tumblr":
                    action = arg;
                    file = argv.shift();
                    if (!neko.FileSystem.exists(file)){
                        throw "File '"+file+"' not found.";
                    }
                default:
                    throw "Unknown option '"+arg+"'";
            }
        }

        switch (action){
            case "picasa":
                neko.Lib.println("Synchronizing picasa files");
                Picasync.sync("./picasa/", "Blog");

            case "tumblr":
                neko.Lib.println("Synchronizing blog "+file);
                var src = neko.io.File.getContent(file);
                var bak = src;
                var foo = OrgParser.parse(src);
                var lst = foo.children;
                if (reverse){
                    lst = new List();
                    for (c in foo.children)
                        lst.push(c);
                }
                for (c in lst){
                    var id = App.postOrgNode(foo, c, credfile, staticUrl);
                    src = TumblrId.addPostIdToOrgNode(src, c, id);
                    if (bak != src){
                        neko.Lib.println("Updating modified org file");
                        var out = neko.io.File.write(file, true);
                        out.writeString(src);
                        out.close();
                        bak = src;
                    }
                }
        }
    }
}