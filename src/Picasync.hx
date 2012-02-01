typedef CacheEntry = {
    mtime:Date,
    md5:String,
    url:String
};
typedef Cache = Hash<CacheEntry>;

class Picasync {

    static function inList(list, name){
        return Lambda.exists(list, function(r) return r.name == name);
    }

    public static function sync(localDir:String, album:String, ?delete=false){
        if (!StringTools.endsWith(localDir, "/"))
            localDir += "/";
        var localCache = new Cache();
        if (neko.FileSystem.exists(localDir+".picasync"))
            localCache = haxe.Unserializer.run(neko.io.File.getContent(localDir+".picasync"));
        var localFiles = neko.FileSystem.readDirectory(localDir);
        var remoteAlbums = Picasa.list();
        if (!inList(remoteAlbums, album))
            Picasa.create(album, true);
        var remoteFiles = Picasa.list(album);
        for (lf in localFiles){
            if (!~/\.(jpg|png|jpeg|gif)$/.match(lf))
                continue;
            if (!inList(remoteFiles, lf))
                localCache.remove(lf);
            if (modified(localDir, lf, localCache)){
                neko.Lib.println("Uploading "+lf+" to album "+album);
                Picasa.post(album, localDir+lf);
            }
        }
        var remoteFiles = Picasa.list(album);
        for (rf in remoteFiles){
            var cache = localCache.get(rf.name);
            if (cache != null){
                neko.Lib.println("Setting url path of "+rf.name+" to "+rf.url);
                cache.url = rf.url;
            }
            else {
                neko.Lib.println("Remote file "+rf.name+" does not exists locally");
            }
        }
        var out = neko.io.File.write(localDir+".picasync", true);
        out.writeString(haxe.Serializer.run(localCache));
        out.close();
    }

    static function modified(path:String, file:String, cache:Cache){
        var meta = cache.get(file);
        if (meta == null){
            meta = {
                mtime: getModificationTime(path+file),
                md5: getMd5(path+file),
                url: null
            }
            cache.set(file, meta);
            return true;
        }
        var mtime = getModificationTime(path+file);
        if (mtime.getTime() <= meta.mtime.getTime())
            return false;
        var md5 = getMd5(path+file);
        var modified = md5 != meta.md5;
        meta.mtime = mtime;
        meta.md5 = md5;
        if (modified)
            meta.url = null;
        return modified;
    }

    inline static function getMd5(file) : String {
        return haxe.Md5.encode(neko.io.File.getContent(file));
    }

    inline static function getModificationTime(file) : Date {
        var stat = neko.FileSystem.stat(file);
        return stat.mtime;
    }
}