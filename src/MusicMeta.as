package 
{
    
    
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.utils.ByteArray;
    
    public class MusicMeta{
        
        public static const stream:FileStream = new FileStream();
        public static const bytes:ByteArray = new ByteArray();
        public var genre:String;
        public  var artist:String;
        public  var trackname:String;
        public  var tracknumber:Number;
        public  var playcount:int;
        public  var album:String;
        public  var rating:int;
        
        public function MusicMeta(id3Meta:Object, m4aMeta:Object=null){
            if(id3Meta){
                var matches:Array = String(id3Meta['TCO']).match("\([0-9]+\)");
               if(matches){
                    this.genre = TCO.GENRES[matches[1]];
               }
               else{
                    this.genre = id3Meta['TCON']?id3Meta['TCON']:id3Meta['TCO'];
                }
                this.artist =  id3Meta['TPE1']?id3Meta['TPE1']:id3Meta['TP1'];
                this.trackname =  id3Meta['TIT2']?id3Meta['TIT2']:id3Meta['TT2'];
                this.tracknumber =  id3Meta['TRCK']?parseInt(id3Meta['TRCK']):parseInt(id3Meta['TRK']);
                this.playcount = 0;
                this.rating = -1;
                this.album =  id3Meta['TALB']? id3Meta['TALB']:id3Meta['TAL'];
            }else{
                this.genre = m4aMeta['gen'];
                this.artist = m4aMeta['ART'];
                this.trackname = m4aMeta['nam'];
                this.tracknumber = parseInt(m4aMeta['trkn']);
                this.playcount = 0;
                this.rating = -1;
                this.album = m4aMeta['alb'];
            }
        }
        
        public static function loadID3(resource:File):MusicMeta
        {
            try{
                
                const tags:Object = {};
                stream.open(resource, FileMode.READ);
                if(resource.extension.toLowerCase() == "m4a"){
                    return  loadM4vTags(resource);
                }    
                
                var val:int = 0;
                scanToBytes([0x49,0x44,0x33], stream);
                
                var versionMajor:int= stream.readByte();
                var versionMinor:int= stream.readByte();
                
                if(versionMajor > 5){
                    scanToBytes([0x49,0x44,0x33], stream);
                    versionMajor= stream.readByte();
                    versionMinor= stream.readByte();
                }
                var labelLength:int = 4;
                var sizeLength:int = 2;
                if(versionMajor > 2){
                    sizeLength = 4;
                }
                const flags:Array = toBitString(stream.readByte());
                const extendedHeader:Boolean = flags[6] == 1;
                const footer:Boolean = flags[4] == 1;
                var frameflags:Array
                var tagsize:int = stream.readInt();
                
                if(extendedHeader){
                    const extendedHeaderSize:int = convertToSyncSafe(stream.readInt());
                    stream.readBytes(bytes, 0, extendedHeaderSize);
                    tagsize -= (extendedHeaderSize + 1);
                }
                var last:int = 0
                while(last == 0x00){
                    last = stream.readByte();
                    tagsize -= 1;
                }
                var id:String = String.fromCharCode(last) + stream.readUTFBytes(labelLength - 1);
                tagsize -= 3;
                var framesize:int;
                if(sizeLength == 4){
                    framesize = convertToSyncSafe(stream.readInt());
                }else{
                    framesize = convertToSyncSafe(stream.readShort());
                }
                tagsize -= sizeLength;
                if(sizeLength == 4){
                    frameflags = [stream.readByte(), stream.readByte()];
                }
                tagsize -= 2;
                var next:int = stream.readByte();
                var tagvalue:String = "";
                
                const encodings:Array = ["ISO-8859-1","UTF-16","UTF-16BE","UTF-8"];
                
                if([0,1,2,3].indexOf(next) == -1){
                    tagvalue =String.fromCharCode(next) + stream.readUTFBytes(framesize - 1) 
                }else{
                    tagvalue= stream.readMultiByte(framesize - 1, encodings[next]);
                }
                tags[id] = tagvalue;
                
                while(tagsize > 0){
                    id = stream.readUTFBytes(labelLength);
                    tagsize -= 3;
                    if(sizeLength == 4){
                        framesize = convertToSyncSafe(stream.readInt());
                    }else{
                        framesize = convertToSyncSafe(stream.readShort());
                    }
                    tagsize -= 4;
                    if(sizeLength == 4){
                        frameflags = [stream.readByte(), stream.readByte()];
                    }
                    tagsize -= 2;
                    next = stream.readByte();
                    
                    if(!framesize || framesize > tagsize){
                        break;
                    }
                    if([0,1,2,3].indexOf(next) == -1){
                        tagvalue =String.fromCharCode(next) + stream.readUTFBytes(framesize - 1) 
                    }else{
                        tagvalue = stream.readMultiByte(framesize - 1, encodings[next]);
                    }
                    tags[id] = tagvalue;
                    tagsize -= framesize;
                    
                    
                }
                
                return new MusicMeta(tags);
            }catch(e:Error){
                trace(e);
            }
            
            return null
        }
        
        private static function loadM4vTags(resource:File):MusicMeta
        {
            const longtags:Array = ["cov","rtn","trk","cpi","dis","tmp","---","gnr","cpr"]; 
            var tags:Object = {};
            scanToBytes([0x69,0x6C,0x73,0x74], stream);
            stream.readInt();
            
            while(true){
                try{
                    var start:int = stream.readByte();
                    var tag:String = stream.readUTFBytes(3);
                    if(start != -87){
                        tag = String.fromCharCode(start) + tag;
                    }
                    var length:int = stream.readInt();
                    stream.readInt();
                    stream.readInt();
                    stream.readInt();
                    var content:String = stream.readUTFBytes(length - 16);
                    tags[tag] = content;
                    stream.readInt();
                }catch(e:Error){
                    break;
                }
            }
            return new MusicMeta(null, tags);
        }
        private static function scanToBytes(bytes:Array, stream:FileStream):FileStream{
            var i:int = 0;
            var match:Array = new Array();
            var max:int = 100000;
            var pos:int = 0;
            while(i++ < bytes.length){
                match.push(stream.readUnsignedByte());
            }
            while(stream.bytesAvailable && !arrEqual(match, bytes) && pos++ < max){
                match.shift();
                match.push(stream.readUnsignedByte());
            }
            if(pos >= max){
                stream.position += stream.bytesAvailable - 10000;
                return scanToBytes(bytes, stream);
            }
            
            return stream;
        }
        
        public static function arrEqual(a:Array,b:Array):Boolean {
            if(a.length != b.length) {
                return false;
            }
            var len:int = a.length;
            for(var i:int = 0; i < len; i++) {
                if(a[i] !== b[i]) {
                    return false;
                }
            }
            return true;
        }
        
        public static function toBitString(num:int, size:int = 8):Array{
            var shift:int = 0;
            var bits:Array = [];
            while(shift < size){
                bits.push((Math.pow(2,shift) & num) >> shift);
                shift++;
            }
            return bits
        }
        
        public static function flush(length:int):String{
            stream.readBytes(bytes, 0, length);
            const ret:String = bytes.toString();
            bytes.clear();
            return ret;
        }
        
        private static function convertToSyncSafe(param0:int):int
        {
            return param0 & 2139062143;
        }
        
        private static function parseTag():Object
        {
            
            return null;
        }
        
    }
}