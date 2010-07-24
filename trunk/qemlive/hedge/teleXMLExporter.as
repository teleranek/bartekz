package qemlive.hedge
{
	public final class TeleXMLExporter
	{
		public function TeleXMLExporter()
		{
		}
		
		public static var loading:uint;
		/*
		exports to file from HEMesh
		*/
		/*
		HEMESH XML:
		<main>
		<!-- FACE -->
			<f>
			0 1 2 <!-- vertex nums -->
			3     <!-- material num -->
			0.5 0.5 <!-- uv's 0 -->
			0.5 0.5 <!-- uv's 1 -->
			0.5 0.5 <!-- uv's 2 -->
			</f>
		<!-- VERTEX -->
			<v>
			x y z
			</v>
		<!-- mat -->
			<m type = "[wire  , solid , tex      ]" >
						color | color | filename
			</m>
		</main<
		*/
		public static function teleXMLExport( model:HEMesh ):Boolean{
			var outFile:String = new String();
			var i:int , matNum:int;
			var f:Face , v:Vertex;
			var mats:Dictionary = new Dictionary();
			var matMap:Array = new Array();
			var typeStr:String , valStr:String;
			
			outFile = "<main>";
			for( i = 0; i < model.numFaces; i++ ){
				f = model.face( i );
				if( !mats[ f.mat ] ){
					matMap.push( f.mat );
					mats[ f.mat ] = matNum++;
				} 
				outFile.concat( "<f>" , String( f.fh.v.vi ) , " " , String( f.fh.nfhi.v.vi ) , " " , String( f.fh.nfhi.nfhi.v.vi ) , " " , 
								String( mats[ f.mat ] )  , " " ,
								String( f.u0 ) , " " , String( f.v0 ) , " " , String( f.u1 ) , " " , 
								String( f.v1 ) , " " , String( f.u2 ) , " " , String( f.v2 ) ,  "</f>\n"
				);
			}
			for( i = 0; i < model.numVertices; i++ ){
				v = Vertex( model.vertices[ i ] );
				outFile.concat( "<v>" , String( v.x ) , " " , String( v.y ) , " " , String( v.z ) ,"</v>\n" );
			}
			for( i = 0; i < matMap.length; i++ ){
				if( matMap[ i ] is WireframeMaterial ){
					typeStr = "wire";
					valStr = String( WireframeMaterial( matMap[ i ] ).fillColor );
				}else if( matMap[ i ] is ColorMaterial ){
					typeStr = "color";
					valStr = String( ColorMaterial( matMap[ i ] ).fillColor );
				}else if( matMap[ i ] is BitmapMaterial ){
					typeStr = "tex";
					valStr = String( /*BitmapMaterial( matMap[ i ] ).bitmap.*/"damn..." );
				}
				outFile.concat( "<m type=\">" , typeStr , "\">" , valStr  , "</m>" );
			}
			outFile = "</main>";
			// BITMAP: mx.graphics.codec jpegencoder...
			return true;
		}
		
		/*
		imports from file to DO3D
		*/
		public static var completeFunction:Function;
		public static const ERROR:int = 0;
		public static const OK:int = 1;
		
		public static function teleXMLImport( s:String ):Boolean{
			var xmlLdr:URLLoader = new URLLoader( );
			try{
				xmlLdr.load( new URLRequest( s ) );
			}
			catch( error:SecurityError ){
				loading = ERROR;
				return false;
			} 
			xmlLdr.addEventListener( IOErrorEvent.IO_ERROR, xmlLdrError );
            xmlLdr.addEventListener( Event.COMPLETE, xmlLdrComplete );
            return true;
		}
		
		private static function xmlLdrError( e:Event ):void{
			loading = ERROR;
		}
		
		private static function xmlLdrComplete( e:Event ):void{
			try{
				var xmlNet:XML = new XML( URLLoader( e.target ).data );
				var reg:RegExp = /[\t\s]+/; // eat-up spaces
				var vs:Array = new Array(); // array of vertices
				var fs:Array = new Array(); // array of faces
				
				var a:Array;
				
				xmlNet.normalize();	
				var mats:Array = new Array();
				var xmlMat:XML;
				for each( xmlMat in xmlNet.elements("m") ){
					// material type ( wire,solid,tex ) ... ( first == main ) 
					if( String( xmlMat.@type ) == "wire" ){
						mats.push( new WireframeMaterial( Number(xmlMat.@color) ) ); 
					}else if( String( xmlMat.@type ) == "solid" ){
						mats.push( new ColorMaterial( Number(xmlMat.@color) ) );
					}else if( String( xmlMat.@type ) == "tex" ){ 
						mats.push( new BitmapFileMaterial( String( xmlMat.@tex ) ) );
					}
				}
				
				var newDo3D:TriangleMesh3D = new TriangleMesh3D( mats[ 0 ] , vs , fs );
				var xmlVertex:XML;
				for each( xmlVertex in xmlNet.elements("v") ){
					a = ( xmlVertex.text()[ 0 ] ).split( reg );
					vs.push( new Vertex3D( a[ 0 ] , a[ 1 ] , a[ 2 ] ) );
				}
				
				var xmlFace:XML;
				for each( xmlFace in xmlNet.elements("f") ){
					a = ( xmlFace.text()[ 0 ] ).split( reg );
					fs.push( new Triangle3D( newDo3D , [ vs[ a[ 0 ] ] , vs[ a[ 1 ] ] , vs[ a[ 2 ] ] ] , mats[ a[ 3 ] ] , 
											[ new NumberUV( a[ 4 ] , a[ 5 ] ) ,
											  new NumberUV( a[ 6 ] , a[ 7 ] ) ,
											  new NumberUV( a[ 8 ] , a[ 9 ] ) 
											] ) ) ; 
				}
				newDo3D.geometry.ready = true;
			}
			catch( e:TypeError ){
				loading = ERROR;
				return;
			}
			
			loading = OK;
			if( completeFunction != null ) completeFunction();
		}
		
		public static function colladaExport( model:HEMesh ):void{
			//DO3DMaker.fromHEMesh( model , mat , 
		}
	}
}