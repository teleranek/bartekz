package qemlive.hedge
{
	import org.papervision3d.core.geom.renderables.Vertex3D;
	import org.papervision3d.core.proto.MaterialObject3D;
	import org.papervision3d.materials.BitmapMaterial;
	import org.papervision3d.materials.special.CompositeMaterial;
	
	import qemlive.Quadric;
	import qemlive.TeleQEM;

	public class Vertex2 extends Vertex
	{
		public var uAvg:Number;
		public var vAvg:Number;
		
		public function Vertex2( )
		{
			uAvg = 0;
			vAvg = 0;
			super(new Vertex3D(),0);
			
		}
		
		public static function fromVertex( v:Vertex , mesh:HEMesh , getUV:Boolean = true ):Vertex2{
			var ret:Vertex2 = new Vertex2();
			var fa:Number;
			ret.edge = v.edge;
			ret.vi = v.vi;
			ret.v = v.v;
			
			if( getUV && (v.vi > -1) ){
				var h:HEdge = v.edge;
				var cnt:Number = 0;
				do{
					if( h.face.q ) cnt+=(fa = h.face.q.area);
					else cnt += ( fa = Quadric.GET_AREA_V( h.face.pv3dFace.v0 , h.face.pv3dFace.v1 , h.face.pv3dFace.v2 ) );
					if( !h.face.pv3dFace.material || !checkMaterial( h.face.pv3dFace.material ) ){
						h = mesh.hedge(h.nvhi);
						continue; 
					} 
					if( h.face.pv3dFace.v0 == v.v ){
						ret.uAvg += h.face.pv3dFace.uv0.u*fa;
						ret.vAvg += h.face.pv3dFace.uv0.v*fa;
					}else if( h.face.pv3dFace.v1 == v.v ){
						ret.uAvg += h.face.pv3dFace.uv1.u*fa;
						ret.vAvg += h.face.pv3dFace.uv1.v*fa;
					}else if( h.face.pv3dFace.v2 == v.v ){
						ret.uAvg += h.face.pv3dFace.uv2.u*fa;
						ret.vAvg += h.face.pv3dFace.uv2.v*fa;
					}else{
						trace("ERROR");
					}
					h = mesh.hedge(h.nvhi);
				}while( h != v.edge );
				
				ret.uAvg /= cnt;
				ret.vAvg /= cnt;
				if( ret.uAvg > 1.0 || ret.uAvg < 0.0 ){
					trace("wrong U");
				}
				if( ret.vAvg > 1.0 || ret.vAvg < 0.0 ){
					trace("wrong V");
				}
			}
			
			return ret;
		}
		
		private static function checkMaterial( mat:MaterialObject3D ):Boolean{
			if( mat is BitmapMaterial ) return true;
			else if( mat is CompositeMaterial ){
				var comp:CompositeMaterial = CompositeMaterial( mat );
				for each( mat in comp.materials ) if( mat is BitmapMaterial ) return true;
				return false;
			}else return false;
		}
		
		public static function COPY( target:Vertex2 , from:Vertex2 ):void{
			Vertex.COPY( target , from );
			
			target.uAvg = from.uAvg;
			target.vAvg = from.vAvg;
		}
		
	}
}