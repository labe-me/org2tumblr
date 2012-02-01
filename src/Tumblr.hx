//
// tumblr-rb wrapper
//
// Author: Laurent Bedubourg <laurent@labe.me>
//

class Tumblr {
    static var TUMBLR = "/usr/bin/tumblr";

    /*
      Post file content to tumblr.

      Returns post ID.
     */
    public static function post(file:String, cred:String) : String {
        var cred = null;
        for (attempt in cred != null ? [cred] : [
            neko.Sys.getCwd()+".tumblr",
            "~/.tumblr"
        ]){
            if (neko.FileSystem.exists(attempt)){
                cred = attempt;
                break;
            }
        }
        if (cred == null){
            throw "Missing .tumblr credential file, please create one.";
        }
        var p = new neko.io.Process(TUMBLR, ["--credentials", cred, file]);
        if (p.exitCode() != 0)
            throw p.stderr.readAll().toString();
        var res = p.stdout.readAll().toString();
        var reg = ~/^Published.*The ID.*is: ([0-9]+)$/;
        if (reg.match(res))
            return reg.matched(1);
        throw res;
    }
}