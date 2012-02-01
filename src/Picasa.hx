//
// Googlecl Picasa command wrapper
//
// Requires googlecl
//
// NOTE:
// You might want to add
//
// skip_auth = True
// user = lbedubourg@gmail.com
//
// to the [PICASA] section of your ~/.config/googlecl/config file.
//
//
// NOTE: beware of jpg->jpeg convertion which occurs during downloads.
//
// Author: Laurent Bedubourg <laurent@labe.me>
//

class Picasa {
    public static var GOOGLE = "/usr/local/bin/google";

    // google picasa create ALBUM
    //
    // Results:
    // Created album: https://picasaweb.google.com/105207523043523759367/Foo?authkey=Gv1sRgCNyq-enLjux
    public static function create(name:String, ?isPublic=false){
        var args = ["picasa", "create", name];
        if (isPublic)
            args.push("--access=public");
        var result = run(GOOGLE, args);
    }

    // google picasa list-albums
    //
    // Results:
    // NAME,URL
    public static function listAlbums(){
        var results = run(GOOGLE, ["picasa","list-albums"]);
        var result = [];
        for (l in results.out.split("\n")){
            if (l.length == 0)
                continue;
            var r = ~/^([^,]+),(http.+)$/;
            if (!r.match(l))
                throw "List albums error\n"+results;
            result.push({name:r.matched(1), url:r.matched(2), time:null});
        }
        return result;
    }

    // google picasa list ALBUM
    //
    // Results:
    // NAME,URL
    public static function listAlbum(name:String){
        var results = run(GOOGLE, ["--fields=title,url-direct,published","picasa","list",name]);
        var result = [];
        for (l in results.out.split("\n")){
            if (l.length == 0)
                continue;
            var r = ~/^([^,]+),(http[^,]+),([^,]+)$/;
            if (!r.match(l))
                throw "List album error\n"+results;
            result.push({name:r.matched(1), url:r.matched(2), time:(r.matched(3))});
        }
        return result;
    }

    public static function list(?album){
        return if (album != null)
            listAlbum(album);
        else
            listAlbums();
    }

    // google picasa get ALBUM --photo=photo
    //
    public static function get(album:String, ?photo:String=null, dest:String) : Array<{name:String, path:String}> {
        var args = ["picasa","get",album,"--dest="+dest];
        if (photo != null)
            args.push("--photo="+photo);
        var result = run(GOOGLE, args);
        var list = [];
        for (line in result.err.split("\n")){
            var reg = ~/^Downloading (.*?) to (.*)$/;
            if (reg.match(line))
                list.push({name:reg.matched(1), path:reg.matched(2)});
        }
        return list;
    }


    // google picasa post ALBUM --src=photo
    //
    // Results:
    // Loading FILE to album ALBUM
    //
    public static function post(album:String, file:String){
        var result = run(GOOGLE, ["picasa","post",album,"--src="+file]);
    }

    // google picasa delete ALBUM [photo]
    public static function delete(album:String, ?photo=null){
        var args = ["picasa","delete",album];
        if (photo != null)
            args.push(photo);
        var result = run(GOOGLE, args, true);
    }

    static var CONF_REG = ~/(Are you SURE.*?\? \(y\/N\): )/;

    static function run(cmd:String, args:Array<String>, confirm=false) : {out:String, err:String}{
        if (confirm)
            args.push("--yes");
        //trace("RUN "+cmd+" "+args.join(" "));
        var p = new neko.io.Process(cmd, args);
        var out = p.stdout.readAll().toString();
        out = CONF_REG.customReplace(out, function(r) return "");
        var err = p.stderr.readAll().toString();
        //trace("OUT "+out);
        //trace("ERR "+err);
        if (p.exitCode() != 0)
            throw err+"\n```"+out;
        p.close();
        return { out:out, err:err };
    }
}