package qemlive.hedge{
	import org.papervision3d.core.geom.renderables.Vertex3D;

	public class Vertex{
		
		public var edge:HEdge; // one of hedges of this v
		public var vi:int; // no of this v
		public var vinitNum:int;
		
		public var v:Vertex3D;
		
		public function Vertex( pv3dv:Vertex3D , vi:uint = 0 , vinit:int = 0){
			this.v = pv3dv;
			pv3dv.extra = this;
			this.vi = vi;
			this.vinitNum = vinit;
		}
		
		public static function COPY( target:Vertex , from:Vertex ):void{
			
			target.v.x = from.v.x;
			target.v.y = from.v.y;
			target.v.z = from.v.z;
			
			// normals
			target.v.normal.copyFrom( from.v.normal );
			
			//target.v = from.v;
		}
		
		public static function EQ( v1:Vertex , v2:Vertex ):Boolean{
			var dx:Number = v1.v.x - v2.v.x;
			var dy:Number = v1.v.y - v2.v.y;
			var dz:Number = v1.v.z - v2.v.z;
			if( dx*dx+dy*dy+dz*dz<1e-14 ){
				return true;
			} 
			else return false;
		}
		
		public static function SUBLEN( v1:Vertex , v2:Vertex ):Number{
			var x:Number = v1.v.x - v2.v.x;
			var y:Number = v1.v.y - v2.v.y;
			var z:Number = v1.v.z - v2.v.z;
			return x*x+y*y+z*z;
		}
		/*
		public static function SUB( v1:Vertex , v2:Vertex ):Vertex{
			return new Vertex( v1.x - v2.x , v1.y - v2.y , v1.z - v2.z , 0 );
		}*/
		
		public static function LEN( v:Vertex ):Number{
			return v.v.x*v.v.x + v.v.y*v.v.y + v.v.z*v.v.z;
		}
		
		public function toString():String{
			return v.x.toFixed( 3 )+"&"+v.y.toFixed(3)+"&"+v.z.toFixed(3);
		}
	}
}