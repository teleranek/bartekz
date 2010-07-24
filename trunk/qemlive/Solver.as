package qemlive
{
	import org.papervision3d.core.math.Number3D;
	
	public final class Solver
	{
		public function Solver()
		{
		}
		
		/*
		counts determinant of a matrix
		*/
		public static function determinant( A:Array ):Number{
			var ord:int = Math.sqrt( A.length );//0.5*( -1 + Math.sqrt( 8*A.length + 1 ) );
			if( ord == 1 ) return A[ 0 ];
			
			var i:int,a:int,b:int;
			var d:Number = 0;
			var pow:int = -1;
			var B:Array = new Array( (ord-1)*(ord-1) );
			for( i = 0; i < ord; i++ ){
				pow *= -1;
    			
    			for( a = ord, b=0; a<A.length && b<B.length; a++){
             		if( (a-i)%ord==0)  continue;                           
             		B[ b++ ] = A[a];
     			}  
				d += pow*A[i]*determinant( B );
			}
			return d;
		}
		
		/*
		tests whether a matrix is a definite-positive matrix
		*/
		public static function definitep( a:Array , g:Array = null  ):Boolean{
			if( a[0]*a[3] - a[1]*a[1] < 0 ) return false;
			else if( a[0]*a[3]*a[5] + a[1]*a[4]*a[2] + a[2]*a[1]*a[4] - a[0]*a[4]*a[4] - a[1]*a[1]*a[5] - a[2]*a[3]*a[2] < 0 ) return false;
			else if( !g ) return true;
			else{
				var b:Number3D = g[ 0 ];
				var c:Number3D = g[ 1 ];
				var d:Number;
				var A:Array = [ a[0],a[1],a[2],-b.x,a[1],a[3],a[4],-b.y,a[2],a[4],a[5],-b.z,-b.x,-b.y,-b.z,1 ];
				if( (d=determinant( A )) < 0 ) 
					return false;
				A = [ a[0],a[1],a[2],-b.x,-c.x,a[1],a[3],a[4],-b.y,-c.y,a[2],a[4],a[5],-b.z,-c.z,-b.x,-b.y,-b.z,1,0,-c.x,-c.y,-c.z,0,1 ]; // LoL
				if( (d=determinant( A )) < 0 ) 
					return false;
				return true;
			}
		}

	}
}