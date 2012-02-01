//
// This module contains a basic org file parser.
//
// Author: Laurent Bedubourg <laurent@labe.me>
//

class OrgNode {
    public var parent : OrgNode;
    public var children : List<OrgNode>;
    public var title : String;
    public var properties : Hash<String>;
    public var level : Int;
    public var state : String;
    public var tags : List<String>;
    public var text : String;

    public function new(?p=null, ?l=0){
        parent = p;
        children = new List();
        properties = new Hash();
        tags = new List();
        level = l;
    }

    public function appendText(line:String){
        if (text == null)
            text = line;
        else
            text += line;
    }

    public function toString() : String {
        var buf = new StringBuf();
        buf.add(level);
        buf.add(" ");
        buf.add(state);
        buf.add(" ");
        buf.add(title);
        buf.add("\n");
        buf.add(properties);
        buf.add("\n");
        buf.add(tags);
        buf.add("\n");
        buf.add("---\n");
        buf.add(text);
        buf.add("\n---");
        buf.add("\n");
        for (c in children)
            buf.add(c.toString());
        return buf.toString();
    }
}

enum OrgParserState {
    NONE;
    PROPERTIES;
}

class OrgParser {
    public static function parse(doc:String) : OrgNode {
        var result = new OrgParser(doc);
        return result.run();
    }

    var state : OrgParserState;
    var root : OrgNode;
    var current : OrgNode;
    var data : String;
    var lines : Array<String>;

    function new(doc){
        data = doc;
    }

    function run() : OrgNode {
        state = NONE;
        root = new OrgNode();
        current = root;
        for (line in data.split("\n"))
            parseLine(line);
        return root;
    }

    function parseLine(line){
        switch (state){
            case NONE:
                var rH = ~/^(\*+)\s+(.*)\s*$/;
                if (rH.match(line)){
                    var stars = rH.matched(1);
                    while (stars.length <= current.level){
                        current = current.parent;
                        if (current == null)
                            throw "MalformedDocument";
                    }
                    current = new OrgNode(current, stars.length);
                    current.parent.children.add(current);
                    parseHeader(rH.matched(2));
                    return;
                }
                var rP = ~/^#\+(.*?): (.*?)$/;
                if (rP.match(line)){
                    var k = rP.matched(1);
                    var v = StringTools.trim(rP.matched(2));
                    current.properties.set(k,v);
                    return;
                }
                var rP = ~/^:PROPERTIES:\s*?$/;
                if (rP.match(line)){
                    state = PROPERTIES;
                    return;
                }
                var stop = false;
                var rC = ~/CLOSED: (\[\d{4}-\d{2}-\d{2} [a-zA-Z]{3} \d{2}:\d{2}\])/;
                if (rC.match(line)){
                    current.properties.set("CLOSED", rC.matched(1));
                    stop = true;
                }
                var rC = ~/SCHEDULED: (<[0-9]{4}-[0-9]{2}-[0-9]{2} [a-zA-Z]{3}>)/;
                if (rC.match(line)){
                    current.properties.set("SCHEDULED", rC.matched(1));
                    stop = true;
                }
                var rC = ~/DEADLINE: (<[0-9]{4}-[0-9]{2}-[0-9]{2} [a-zA-Z]{3}>)/;
                if (rC.match(line)){
                    current.properties.set("DEADLINE", rC.matched(1));
                    stop = true;
                }
                if (stop)
                    return;
                var rD = ~/^(<[0-9]{4}-[0-9]{2}-[0-9]{2} [a-zA-Z]{3}>)$/;
                if (rD.match(line)){
                    current.properties.set("TEXT_DATE", rD.matched(1));
                    return;
                }
                current.appendText(line+"\n");

            case PROPERTIES:
                var rP = ~/^:(.*?):\s*(.*?)$/;
                if (rP.match(line)){
                    var k = rP.matched(1);
                    var v = StringTools.trim(rP.matched(2));
                    if (k == "END"){
                        state = NONE;
                    }
                    else {
                        current.properties.set(k, v);
                    }
                }
        }
    }

    function parseHeader(str){
        current.title = str;
        var reg = ~/^(TODO|DONE)? (.*?)$/;
        if (reg.match(current.title)){
            current.state = reg.matched(1);
            current.title = reg.matched(2);
        }
        var reg = ~/^(.*?)(\s+:[a-zA-Z0-9_:\-]+:)$/;
        if (reg.match(current.title)){
            current.title = reg.matched(1);
            current.tags = Lambda.filter(
                Lambda.map(
                    reg.matched(2).split(":"),
                    function(x) return StringTools.trim(x)),
                function(r) return r != ""
            );
        }
        var rD = ~/(<[0-9]{4}-[0-9]{2}-[0-9]{2} [a-zA-Z]{3}>)/;
        if (rD.match(current.title)){
            current.title = StringTools.replace(current.title, rD.matched(1), "");
            current.properties.set("HEAD_DATE", rD.matched(1));
        }
        current.title = StringTools.trim(current.title);
    }
}