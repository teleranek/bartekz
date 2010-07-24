package qemlive.hedge
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Dictionary;
	
	import org.papervision3d.core.geom.Lines3D;
	import org.papervision3d.core.geom.Particles;
	import org.papervision3d.core.geom.TriangleMesh3D;
	import org.papervision3d.core.geom.renderables.Particle;
	import org.papervision3d.core.geom.renderables.Triangle3D;
	import org.papervision3d.core.geom.renderables.Vertex3D;
	import org.papervision3d.core.math.Number3D;
	import org.papervision3d.core.math.NumberUV;
	import org.papervision3d.core.proto.MaterialObject3D;
	import org.papervision3d.materials.BitmapFileMaterial;
	import org.papervision3d.materials.BitmapMaterial;
	import org.papervision3d.materials.ColorMaterial;
	import org.papervision3d.materials.WireframeMaterial;
	import org.papervision3d.materials.special.LineMaterial;
	import org.papervision3d.materials.special.ParticleMaterial;
	import org.papervision3d.objects.DisplayObject3D;
	
	import qemlive.TeleQEM;
	import qemlive.timers.MakerTimer;
	
	public class DO3DMaker
	{
		/*
		faceHEdges( mesh , color  , size          ):lines3d;
		edgeHEdges( mesh , color1 , color2 , size ):do3d;
		facePoints( mesh , color                  ):particles;
		edgePoints( mesh , color                  ):particles;
		fromHEMesh( mesh , mat                    ):trianglemesh3d;
		*/
		public static function faceHEdges( mesh:HEMesh , color:uint = 0xffffff , size:Number = 1 ):Lines3D{
			var lines:Lines3D = new Lines3D( new LineMaterial( color ) );
			var face:Face;
			var cur:HEdge , first:HEdge;
			
			for( var i:uint = 0; i < mesh.numFaces; i++ ){
				face = mesh.face( i );
				
				//if( !frontFacing( face , mesh ) ) continue;
				cur = first = face.fh;
				do{
					lines.addNewLine( size , cur.v.x , cur.v.y , cur.v.z , cur.nfhi.v.x , cur.nfhi.v.y , cur.nfhi.v.z );
					cur = cur.nfhi;
				}while( cur != first );
			}
			return lines;
		}
		
		public static function edgeHEdges( mesh:HEMesh , color1:uint = 0xff0000 , color2:uint = 0x00ff00 , size:Number = 1 ):DisplayObject3D{
			var lines0:Lines3D = new Lines3D( new LineMaterial( color1 ) );
			var lines1:Lines3D = new Lines3D( new LineMaterial( color2 ) );
			var face:Face;
			var c1:Number3D , c2:Number3D;
			var cur:HEdge , first:HEdge , h:HEdge;
			var opposite:Boolean;
			
			for( var i:uint = 0; i < mesh.numFaces; i++ ){
				face = mesh.face( i );
				c1 = faceCenter( face , mesh );
				cur = first = face.fh;
				do{
					opposite = cur.isNextEdgeHEdgeOpposite();
					for( h = cur.nehi; h != cur; h = h.nehi ){
						c2 = faceCenter( h.face , mesh );
						if( opposite ){
							lines0.addNewLine( size , c1.x , c1.y , c1.z , c2.x , c2.y , c2.z );
						}else{
							lines1.addNewLine( size , c1.x , c1.y , c1.z , c2.x , c2.y , c2.z );
						}
						opposite = ( opposite == h.isNextEdgeHEdgeOpposite() );
					}
					
					cur = cur.nfhi;
				}while( cur != first );
			}
			
			var do3d:DisplayObject3D = new DisplayObject3D();
			do3d.addChild( lines0 );
			do3d.addChild( lines1 );
			return do3d;
		}
		
		public static function facePoints( mesh:HEMesh , particles:Particles = null , color:uint = 0x00ffff , size:Number = 8 ):Particles{
			if( !particles ) particles = new Particles();
			var pm:ParticleMaterial = new ParticleMaterial( color , 1 );
			var c:Number3D;
			
			for( var i:uint = 0; i < mesh.numFaces; i++ ){
				c = faceCenter( mesh.face( i ) , mesh );
				particles.addParticle( new Particle( pm , size , c.x , c.y , c.z ) );
			}
			return particles;
		}
		
		public static function edgePoints( mesh:HEMesh , particles:Particles = null , color:uint = 0xffff00 , size:Number = 8 ):Particles{
			if( !particles ) particles = new Particles();
			var pm:ParticleMaterial = new ParticleMaterial( color , 1 );
			var c:Number3D;
			var first:HEdge , cur:HEdge;
			var num:uint = 0;
			
			for( var i:uint = 0; i < mesh.numFaces; i++ ){
				c = Number3D.ZERO;
				num = 0;
				first = mesh.face( i ).fh;
				cur = first;
				do{
					c.x += cur.nfhi.v.x;
					c.y += cur.nfhi.v.y;
					c.z += cur.nfhi.v.z;
					++num;
					cur = mesh.hedge( cur.nvhi );
				}while( cur != first );
				c.multiplyEq( 1.0/num );
				particles.addParticle( new Particle( pm , size , c.x , c.y , c.z ) );
			}
			return particles;
		}
		
		public static var currentDo3D:TriangleMesh3D;
		public static function fromHEMesh( mesh:HEMesh , onFinish:Function = null, mat:MaterialObject3D = null ):void{
			var mtime:MakerTimer = new MakerTimer( 20 , mat , mesh , onFinish );
			currentDo3D = null;
			mtime.addEventListener( TimerEvent.TIMER , fromHEMeshPart );
			mtime.start();
		}
		
		private static function fromHEMeshPart( evt:TimerEvent ):void{
			var face:Face;
			var f:Triangle3D;
			var vert:Vertex3D;
			var v:Array = new Array( 3 );
			var uv:Array = new Array( 3 );
			var hedges:uint;
			var cur:HEdge , first:HEdge;
			var i:int;
			
			var mtime:MakerTimer = (MakerTimer)(evt.target);
			var mat:MaterialObject3D = mtime.mat;
			var mesh:HEMesh = mtime.mesh;
			var mats:Dictionary = mtime.mats;
			var newDo3D:TriangleMesh3D = mtime.newDo3D;
			var vertices:Array = mtime.newDo3D.geometry.vertices;
			var faces:Array = mtime.newDo3D.geometry.faces;
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Exporting mesh to do3d: " + String( mesh.numFaces - TeleQEM.TIMERCOUNT_LIGHT*mtime.currentCount );
			var lines:Lines3D = new Lines3D( new LineMaterial( 0x00ff00 ) );
			// addin facez
			for ( i = TeleQEM.TIMERCOUNT_LIGHT*mtime.currentCount; 
			      ( i < mesh.numFaces )&&( i < TeleQEM.TIMERCOUNT_LIGHT*(mtime.currentCount+1) ); i++ )
			{
				face = mesh.face( i );
				hedges = 0;
				cur = first = face.fh;
				do{
					if( vertices[ cur.v.vi ] == null ){

						var vertex:Vertex = cur.v;
						var v3d:Vertex3D;
						if( vertex == null ){
							v3d = new Vertex3D( 0,0,0 );
						} 
						else{
							v3d = new Vertex3D( vertex.x , vertex.y , vertex.z );
							v3d.normal.x = vertex.nx;
							v3d.normal.y = vertex.ny;
							v3d.normal.z = vertex.nz;
						}
						vertices[ cur.v.vi ] = v3d;
					}
					v[ hedges++ ] = vertices[ cur.v.vi ];
					//lines.addNewLine( 1 , cur.v.x , cur.v.y , cur.v.z , cur.nfhi.v.x , cur.nfhi.v.y , cur.nfhi.v.z );
					cur = cur.nfhi;
				}while( cur != first );
				
				//if( ( cur.v.x != v[0].x) || ( cur.v.y != v[0].y ) || ( cur.v.z != v[0].z ) ){
				//	trace("wtf?");
				//}
				//lines.addNewLine( 1 , v[0].x , v[0].y , v[0].z , v[1].x , v[1].y , v[1].z );
				//lines.addNewLine( 1 , v[1].x , v[1].y , v[1].z , v[2].x , v[2].y , v[2].z );
				//lines.addNewLine( 1 , v[2].x , v[2].y , v[2].z , v[0].x , v[0].y , v[0].z );
				//if( hedges != 3 ) trace( "Invalid mesh, says fromHEMesh" );
				
				if( face.mat && !mats[ face.mat ] ){
					mats[ face.mat ] = true;
					face.mat.registerObject( newDo3D );
				} 
				faces.push( f = new Triangle3D( newDo3D , v , mat?mat:face.mat , 
												[ new NumberUV( face.u0 , face.v0 ) , 
												  new NumberUV( face.u1 , face.v1 ) , 
												  new NumberUV( face.u2 , face.v2 ) ] 
											   ) );
				f.faceNormal.x = face.nx;
				f.faceNormal.y = face.ny;
				f.faceNormal.z = face.nz;
			}
			
			if( i == mesh.numFaces ){
				newDo3D.geometry.ready = true;
				mtime.stop();
				currentDo3D = newDo3D;
				//currentDo3D.addChild( lines );
				if( mtime.onFinish != null ) mtime.onFinish();
			}
			return ;
		}
		
		
		private static function frontFacing( f:Face , m:HEMesh ):Boolean{
			var cur:HEdge;
			var first:HEdge = f.fh;
			var i:uint;
			var x:Number , y:Number , z:Number;
			var v:Array = new Array(3);
			
			var transform:Number = 1; /* model nasz stoi sobie na srodku */
			cur = first;
			do{
				x = transform*cur.v.x;
				y = transform*cur.v.y;
				z = transform*cur.v.z;
				v[ i++ ] = new Number3D( x , y , z );
				cur = cur.nfhi;
			}while( cur != first );
			
			var norm:Number3D;
			( norm = Number3D.cross( Number3D.sub( v[ 1 ] , v[ 0 ] ) , Number3D.sub( v[ 2 ] , v[ 0 ] ) ) ).normalize();
			
			return ( Number3D.dot( norm , v[ 0 ] ) < 0 );
		}
		
		private static function faceCenter( f:Face , m:HEMesh ):Number3D{
			var sumX:Number = 0, sumY:Number = 0 , sumZ:Number = 0;
			var cnt:int = 0;
			
			var cur:HEdge;
			var first:HEdge = f.fh;
			
			cur = first;
			do{
				++cnt;
				sumX += cur.v.x;
				sumY += cur.v.y;
				sumZ += cur.v.z;
				
				cur = cur.nfhi;
			}while( cur != first );
			
			return new Number3D( sumX/cnt , sumY/cnt , sumZ/cnt );
		}
				
		public function DO3DMaker()
		{
		}

	}
}