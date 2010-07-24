package qemlive.hedge
{
	import org.papervision3d.core.geom.renderables.Vertex3D;
	import org.papervision3d.core.math.AxisAlignedBoundingBox;
	import org.papervision3d.core.math.Number3D;
	
	/*
	AABB with expanding and std deriv
	*/
	public class AABB extends AxisAlignedBoundingBox
	{
		private var e:Number3D;
		private var e2:Number3D;
		private var n:uint;
		
		public function AABB(minX:Number=Number.POSITIVE_INFINITY, minY:Number=Number.POSITIVE_INFINITY, minZ:Number=Number.POSITIVE_INFINITY, maxX:Number=Number.NEGATIVE_INFINITY, maxY:Number=Number.NEGATIVE_INFINITY, maxZ:Number=Number.NEGATIVE_INFINITY)
		{
			e = new Number3D(); e2 = new Number3D(); n = 0;
			super(minX, minY, minZ, maxX, maxY, maxZ); 
		}
		
		public function get center():Number3D{
			return new Number3D( (minX + maxX)*0.5 , (minY + maxY)*0.5 , (minZ + maxZ)*0.5 );
		}
		
		public function get size():Number3D{
			return new Number3D( (maxX-minX), (maxY-minY) , (maxZ-minZ) );
		}
		
		public function expand( v:Vertex3D ):void{
			if( v.x < minX ) minX = v.x;
			if( v.y < minY ) minY = v.y;
			if( v.z < minZ ) minZ = v.z;
			if( v.x > maxX ) maxX = v.x;
			if( v.y > maxY ) maxY = v.y;
			if( v.z > maxZ ) maxZ = v.z;
			e.x += v.x; e.y += v.y; e.z += v.z;
			e2.x+= v.x*v.x; e2.y+= v.y*v.y; e2.z+= v.z*v.z; 
			n++;
		}
		
		public function get expected():Number3D{
			return new Number3D( e.x/n, e.y/n , e.z/n );
		}
		
		public function get variance():Number3D{
			var _ex:Number = e.x/n;
			var _ey:Number = e.y/n;
			var _ez:Number = e.z/n;
			var _e2x:Number = e2.x/n;
			var _e2y:Number = e2.y/n;
			var _e2z:Number = e2.z/n;
			return new Number3D( _e2x - _ex*_ex , _e2y - _ey*_ey , _e2z - _ez*_ez );
		}
		
		public function get stddev():Number3D{
			var _ex:Number = e.x/n;
			var _ey:Number = e.y/n;
			var _ez:Number = e.z/n;
			var _e2x:Number = e2.x/n;
			var _e2y:Number = e2.y/n;
			var _e2z:Number = e2.z/n;
			return new Number3D( Math.sqrt(_e2x - _ex*_ex), Math.sqrt(_e2y - _ey*_ey) , Math.sqrt(_e2z - _ez*_ez) );
		}
	}
	
}