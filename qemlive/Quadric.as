package qemlive
{
	import org.papervision3d.core.geom.renderables.Triangle3D;
	import org.papervision3d.core.geom.renderables.Vertex3D;
	import org.papervision3d.core.math.Number3D;
	
	import qemlive.hedge.Face;
	import qemlive.hedge.HEMesh;
	import qemlive.hedge.Vertex;
	import qemlive.hedge.Vertex2;
	
	public class Quadric
	{
		/*
		Quadric(
		 g = array of number3d's
		 v = vertex used to compute Quadric
		*/
		public static const ATTRIBUTE_COEFF:Number = 100;
		
		public var C:Array;
		public var b:Array;
		public var c:Number;
		public var g:Array;
		public var lambda:Number;
		public var area:Number;
		/*
		corresponding HEdge
		*/
		public var param:uint;
		//public function set param( u:uint ):void{ if( u == 140 ){ trace("set to 140"); } _param = u; }
		//public function get param( ):uint{ return _param; }
		/*
		position in heap
		*/
		public var pos:uint;
		
		/*
		minimized Vertex stored.
		*/
		public var v:Vertex2;
		
		public var value:Number;
		
		public function Quadric( C:Array , b:Array , c:Number , g:Array , area:Number , lambda:Number )
		{
			this.g = g;
			this.C = C;
			this.c = c;
			this.b = b;
			this.lambda = lambda;
			this.area = area;
			this.pos = ~0;
		}
		
		public function compute( vv:Vertex2 ):Number{
		/* 
		v*A*v + 2*b*v + c
		*/	
			var i:int
			var attributes:uint = g.length;
			var dim:uint = attributes + 3;
			// v*A 
			
			// first three positions in vector
			/*
			     C0  C1  C2 gix
			A =  C1  C3  C4 giy ...
			     C2  C4  C5 giz 
			     gix giy giz .
                    ...          . 
                              lambda
                                  .    			
			*/
			var v0:Number , v1:Number , v2:Number;
			var sumx:Number , sumy:Number , sumz:Number;
			v0 = vv.v.x*C[0] + vv.v.y*C[1] + vv.v.z*C[2];
			v1 = vv.v.x*C[1] + vv.v.y*C[3] + vv.v.z*C[4];
			v2 = vv.v.x*C[2] + vv.v.y*C[4] + vv.v.z*C[5];
			
			sumx = sumy = sumz = 0;
			var vec:Array = new Array( dim );
			vec[ 0 ] = vv.v.x;
			vec[ 1 ] = vv.v.y;
			vec[ 2 ] = vv.v.z;
			if( attributes >= TeleQEM.INTERPOLATE_UV ){
				vec[ 3 ] = vv.uAvg;
				vec[ 4 ] = vv.vAvg;
			}
			if( attributes == TeleQEM.INTERPOLATE_UV_AND_NORMALS ){
				vec[ 5 ] = vv.v.normal.x;
				vec[ 6 ] = vv.v.normal.y;
				vec[ 7 ] = vv.v.normal.z;
			}
			
			for( i = 0; i < attributes; i++ ){
				sumx += vec[ i+3 ]*g[ i ].x;
				sumy += vec[ i+3 ]*g[ i ].y;
				sumz += vec[ i+3 ]*g[ i ].z;
			}
			
			var vecMultiplied:Array = new Array( attributes );
			vecMultiplied[ 0 ] = v0 - sumx; // NOTE: changed signs <--
			vecMultiplied[ 1 ] = v1 - sumy;
			vecMultiplied[ 2 ] = v2 - sumz;
			for( i = 0; i < attributes; i++ ){
				vecMultiplied[ i+3 ] = -vv.v.x*g[i].x - vv.v.y*g[i].y - vv.v.z*g[i].z + ATTRIBUTE_COEFF*vec[i+3];
			}
			
			// VMult*v + 2*b*v + c
			value = 0;
			for( i = 0; i < dim; i++ ){
				value += vecMultiplied[ i ]*vec[ i ];
				value += 2*b[ i ]*vec[ i ];
			}
			
			value += c;
			value *= area;
			if( value < 0 ){
				value = 0;
			}
			value = -value;
			return value;
		}
		
		public static function ZERO( attributes:uint ):Quadric{
			var arr:Array = new Array( 6 );
			var b:Array = new Array( attributes + 3 );
			var g:Array = new Array( attributes );
			var i:int;
			for( i = 0; i < 6; i++ ) arr[i] = 0.0;
			for( i = 0; i < attributes; i++ ) g[ i ] = Number3D.ZERO;
			for( i = 0; i < b.length; i++ ) b[ i ] = 0.0;
			return new Quadric( arr , b , 0 , g , 0 , 0 );
		}
		
		public static function COPY( q:Quadric ):Quadric{
			var arr:Array = new Array( 6 );
			var b:Array = new Array( q.g.length + 3 );
			var g:Array = new Array( q.g.length );
			var i:int;
			for( i = 0; i < 6; i++ ) arr[i] = q.C[ i ];
			for( i = 0; i < q.g.length; i++ ) g[ i ] = Number3D( q.g[ i ] ).clone();
			for( i = 0; i < b.length; i++ ) b[ i ] = q.b[ i ];
			return new Quadric( arr , b , q.c , g , q.area , q.lambda );
			//return newq;
		}
		
		public function add( q:Quadric ):void{
			var i:int;
			
			lambda += q.lambda;
			area += q.area;
			c += q.c;
			
			for( i = 0; i < 6; i++ ) C[ i ] += q.C[ i ];
			for( i = 0; i < g.length; i++ ) g[ i ].plusEq( q.g[ i ] );
			for( i = 0; i < b.length; i++ ) b[ i ] += q.b[ i ];
			
		}
		
		public function copy( q:Quadric ):void{
			var i:int;
			
			lambda = q.lambda;
			area = q.area;
			c = q.c;
			
			for( i = 0; i < 6; i++ ) C[ i ] = q.C[ i ];
			for( i = 0; i < g.length; i++ ) Number3D( g[ i ] ).copyFrom( q.g[ i ] );
			for( i = 0; i < b.length; i++ ) b[ i ] = q.b[ i ];
		}
		
/*
		MINIMIZE IS TURNED OFF CAUSE IN LIVE MODE WE ARE COLLAPSIN TO EXISTING VERTICES AND LEAVIN EVERYTHIN UNCHANGED 
		
//		returns the Vertex which minimizes this Quadric
		public function minimize( ):Vertex2{
			
//			to obtain p
//			we must solve
//			( C - 1/lambda*B*B )p = b1-1/lambda*B*b2
//			B = g's
//			b1 = 3 first b's
//			b2 = remaining b's
			var i:int;
			var gi:Number3D;
			var il:Number = 1/lambda;
			
			
//			if( !Solver.definitep( C , g.length?g:null ) ){
//				trace("indefinite mtx!");
//				return null;
//			}
			// numbers instead of arrays to speed-up process and save time for searching i'th element of array
			var n11:Number , n12:Number , n13:Number , n14:Number , 
							 n22:Number , n23:Number , n24:Number , 
										  n33:Number , n34:Number;
			
			var sumxx:Number , sumxy:Number , sumxz:Number , sumyy:Number , sumyz:Number , sumzz:Number;
			
			n11 = C[0]; n12 = C[1]; n13 = C[2]; 
						n22 = C[3]; n23 = C[4];
									n33 = C[5];
			sumxx = 0; sumxy = 0; sumxz = 0; sumyy = 0; sumyz = 0; sumzz = 0;
			
			for each( gi in g ){
				sumxx += gi.x*gi.x;
				sumxy += gi.x*gi.y;
				sumxz += gi.x*gi.z;
				sumyy += gi.y*gi.y;
				sumyz += gi.y*gi.z;
				sumzz += gi.z*gi.z;
			}
			sumxx *= il; sumxy *= il; sumxz *= il; 
			sumyy *= il; sumyz *= il; sumzz *= il;
			n11 -= sumxx; n12 -= sumxy; n13 -= sumxz;
						  n22 -= sumyy; n23 -= sumyz;
										n33 -= sumzz;
			
			// now coefficients of result
			n14 = -b[ 0 ]; n24 = -b[ 1 ]; n34 = -b[ 2 ];
			sumxx = 0; sumxy = 0; sumxz = 0;
			for( i = 0; i < g.length; i++ ){
				sumxx -= g[ i ].x*b[ i+3 ];
				sumxy -= g[ i ].y*b[ i+3 ];
				sumxz -= g[ i ].z*b[ i+3 ];
			}
			sumxx *= il; sumxy *= il; sumxz *= il;
			n14 += sumxx; n24 += sumxy; n34 += sumxz;
			
			// now detA, from Cramer's Rule
//			n11 n12 n13
//			n12 n22 n23
//			n13 n23 n33
			var detA:Number = (n11 * n22 - n12 * n12) * n33 - (n11 * n23 - n13 * n12) * n23 + (n12 * n23 - n13 * n22) * n13;
			if( (detA > -0.001) && ( detA < 0.001 ) ){
				//trace( "detA was " + String(detA) + "  in minimize" );
				return null;
			}
			
//			n14 n12 n13
//			n24 n22 n23
//			n34 n23 n33
			var detX:Number = (n14 * n22 - n24 * n12) * n33 - (n14 * n23 - n34 * n12 ) * n23 + (n24 * n23 - n34 * n22) * n13;
			
//			n11 n14 n13
//			n12 n24 n23
//			n13 n34 n33
			var detY:Number = (n11 * n24 - n14 * n12) * n33 - (n11 * n34 - n13 * n14) * n23 + (n12 * n34 - n13 * n24) * n13;
			
//			n11 n12 n14
//			n12 n22 n24
//			n13 n23 n34
			var detZ:Number = (n11 * n22 - n12 * n12) * n34 - (n11 * n23 - n13 * n12) * n24 + (n12 * n23 - n13 * n22) * n14;
			
			var ret:Vertex2 = new Vertex2();
			
			ret.x = detX/detA;
			ret.y = detY/detA;
			ret.z = detZ/detA;
			
			
//			To obtain set of attibute values, we must compute
//			s = (1/lambda)*(b2 - B*p)
//			p = ret
			
			if( g.length >= 2 ){
				ret.uAvg = Math.max( 0 , Math.min( 1 , il*( -b[3] + g[0].x*ret.x + g[0].y*ret.y + g[0].z*ret.z ) ) );
				ret.vAvg = Math.max( 0 , Math.min( 1 , il*( -b[4] + g[1].x*ret.x + g[1].y*ret.y + g[1].z*ret.z ) ) );
			}
			if( g.length == 5 ){
				ret.nx = il*( -b[5] + g[2].x*ret.x + g[2].y*ret.y + g[2].z*ret.z );
				ret.ny = il*( -b[6] + g[3].x*ret.x + g[3].y*ret.y + g[3].z*ret.z );
				ret.nz = il*( -b[7] + g[4].x*ret.x + g[4].y*ret.y + g[4].z*ret.z );
			}
			this.v = ret;
			return ret;
		}
*/
		
		public static function fromFace( face:Face , attributes:uint , scaleLambda:Number = 1 ):Quadric{

//			Qf(v) = (A,b,c)= 
//			n*n + g[i]*g[i]
//			lambda[i]
//			d, d[j]
//			v*A*v + 2dnv + c
//			
//			We have these attibutes:
//			u, v, normals( nx,ny,nz) => m=5
			
			if( !face.valid ){
				return Quadric.ZERO( attributes );
			} 
			var f:Triangle3D = face.pv3dFace;
			var g:Array; // = g[i]
			var dv:Array; // = d[i]
			var d:Number;
			var area:Number;
			var i:int;
		
			var p1:Vertex3D = face.fh.v.v;
			var p2:Vertex3D = face.fh.nfhi.v.v;
			var p3:Vertex3D = face.fh.nfhi.nfhi.v.v;
			
			area = Quadric.GET_AREA_V( p1 , p2 , p3 , scaleLambda);
			
			//THIs FIXES SOME THINGS:
			//if( area < 0.001 ) return Quadric.ZERO( attributes );
			
			// d = -n*p1 ( n*p1 )
			d = -(f.faceNormal.x*p1.x + f.faceNormal.y*p1.y + f.faceNormal.z*p1.z);
			
			/*
				we solve linear system:
				p1 1 | s1
				p2 1 | s2
				p3 1 | s3
				n  1 | 0
			*/
			
			var detA:Number = (attributes==TeleQEM.INTERPOLATE_NOTHING)?0:getDet4x4( p1 , p2 , p3 , f , 0 );
			if( attributes && ( detA == 0 ) ){
				trace( "Determinant was 0" );
				return Quadric.ZERO( attributes );
			}
			g = new Array();
			dv = new Array();
			//var chk:Number;
			
			var paramVal:Number;
			for( i = 0; i < attributes; i++ ){
				var gElem:Number3D = new Number3D( getDet4x4( p1,p2,p3,f,1,i)/detA ,
												   getDet4x4( p1,p2,p3,f,2,i)/detA , 
												   getDet4x4( p1,p2,p3,f,3,i)/detA );
				g.push( gElem );
				//chk = getDet4x4( p1,p2,p3,f,4,i)/detA;
				
				if( i == 0 ) paramVal = f.uv0.u;
				else if( i == 1 ) paramVal = f.uv0.v;
				else if( i == 2 ) paramVal = p1.normal.x;
				else if( i == 3 ) paramVal = p1.normal.y;
				else paramVal = p1.normal.z; 
				dv.push( -p1.x*gElem.x - p1.y*gElem.y - p1.z*gElem.z + paramVal );// NOTE:changed sign
				/*
				if( chk != dv[i] ){
					trace("dv not chk");
				}
				*/
			}
			/*
			nnT = outer product matrix of a normal = 
		     aa ab ac
		     ab bb bc
		     ac bc cc
		     C = nnT + sum( gj*gjT) = Array(6) since it's a simmetrical Matrix
		     = aa[0] ab[1] ac[2]
		             bb[3] bc[4]
		                   cc[5] , a[ 2*i + j ] = C[ i , j ]
			*/
			var C:Array = new Array( 6 );
			C[ 0 ] = f.faceNormal.x*f.faceNormal.x;
			C[ 1 ] = f.faceNormal.x*f.faceNormal.y;
			C[ 2 ] = f.faceNormal.x*f.faceNormal.z;
			C[ 3 ] = f.faceNormal.y*f.faceNormal.y;
			C[ 4 ] = f.faceNormal.y*f.faceNormal.z;
			C[ 5 ] = f.faceNormal.z*f.faceNormal.z;//C[0]=C[1]=C[2]=C[3]=C[4]=C[5]=0;
			for( i = 0; i < attributes; i++ ){
				C[ 0 ] += g[ i ].x*g[ i ].x
				C[ 1 ] += g[ i ].x*g[ i ].y;
				C[ 2 ] += g[ i ].x*g[ i ].z;
				C[ 3 ] += g[ i ].y*g[ i ].y;
				C[ 4 ] += g[ i ].y*g[ i ].z;
				C[ 5 ] += g[ i ].z*g[ i ].z;
			}
			
			/*
			b Array is a vector of dv's and d*n + sum(dv*g)
			c is a scalar = d*d + sum( dv*dv )
			*/
			var b:Array = new Array( attributes + 3 );
			var c:Number = d*d;
			b[ 0 ] = d*f.faceNormal.x;
			b[ 1 ] = d*f.faceNormal.y;
			b[ 2 ] = d*f.faceNormal.z;
			for( i = 0; i < attributes; i++ ){
				b[ 0 ] += dv[ i ]*g[ i ].x;
				b[ 1 ] += dv[ i ]*g[ i ].y;
				b[ 2 ] += dv[ i ]*g[ i ].z;
				b[ 3+i ] = -dv[ i ];
				
				c += dv[ i ]*dv[ i ];
			}
			
			/*
			now we have:
			g[i]'s for attibutes
			d[i]'s for attributes
			C Matrix
			lambda = area of f
			*/
			return new Quadric( C , b , c , g , area , 1 );
		}
		
		private static function getDet4x4( p1:Vertex3D , p2:Vertex3D , p3:Vertex3D , f:Triangle3D , type:uint , param:uint = 0 ):Number{
			/*	 to make it faster, we dont use matrices 
			determinant of 
				p1.x p1.y p1.z 1           p2x p2y p2z       p1x p1y p1z       p1x p1y p1z
				p2.x p2.y p2.z 1  =  - det p3x p3y p3z + det p3x p3y p3z - det p2x p2y p2z
				p3.x p3.y p3.z 1           nx  ny  nz        nx  ny  nz        nx  ny  nz
				n.x  n.y  n.z  0

			*/
			var fx:Number = f.faceNormal.x;
			var fy:Number = f.faceNormal.y;
			var fz:Number = f.faceNormal.z;
			
			if( type == 0 ){
				return -( p2.x*p3.y*fz + p2.y*p3.z*fx + p2.z*p3.x*fy - p2.z*p3.y*fx - p2.y*p3.x*fz - p2.x*p3.z*fy )
					   +( p1.x*p3.y*fz + p1.y*p3.z*fx + p1.z*p3.x*fy - p1.z*p3.y*fx - p1.y*p3.x*fz - p1.x*p3.z*fy )
					   -( p1.x*p2.y*fz + p1.y*p2.z*fx + p1.z*p2.x*fy - p1.z*p2.y*fx - p1.y*p2.x*fz - p1.x*p2.z*fy );
			}else{ 
				var s1:Number , s2:Number , s3:Number;
				if( param == 0 ){
					s1 = f.uv0.u;
					s2 = f.uv1.u;
					s3 = f.uv2.u;
				}else
				if( param == 1 ){
					s1 = f.uv0.v;
					s2 = f.uv1.v;
					s3 = f.uv2.v;
				}else
				if( param == 2 ){
					s1 = p1.normal.x;
					s2 = p2.normal.x;
					s3 = p3.normal.x;
				}else
				if( param == 3 ){
					s1 = p1.normal.y;
					s2 = p2.normal.y;
					s3 = p3.normal.y;
				}else
				if( param == 4 ){
					s1 = p1.normal.z;
					s2 = p2.normal.z;
					s3 = p3.normal.z;
				} else return 0;
			/* determinant of 
				s1 p1.y p1.z 1           s2 p2y p2z       s1 p1y p1z       s1 p1y p1z
				s2 p2.y p2.z 1  =  - det s3 p3y p3z + det s3 p3y p3z - det s2 p2y p2z
				s3 p3.y p3.z 1            0  ny  nz        0  ny  nz        0  ny  nz
				0  n.y  n.z  0
				
			*/
				if( type == 1 ){
					return -( s2*p3.y*fz + p2.z*s3*fy - p2.y*s3*fz - s2*p3.z*fy )
					   	   +( s1*p3.y*fz + p1.z*s3*fy - p1.y*s3*fz - s1*p3.z*fy )
					   	   -( s1*p2.y*fz + p1.z*s2*fy - p1.y*s2*fz - s1*p2.z*fy );
				}else
				/* determinant of 
				p1.x s1 p1.z 1           p2x s2 p2z       p1x s1 p1z       p1x s1 p1z
				p2.x s2 p2.z 1  =  - det p3x s3 p3z + det p3x s3 p3z - det p2x s2 p2z
				p3.x s3 p3.z 1            nx  0  nz        nx  0  nz        nx  0  nz
				n.x  0  n.z  0
			*/	if( type == 2 ){
					return -( p2.x*s3*fz + s2*p3.z*fx - p2.z*s3*fx - s2*p3.x*fz )
						   +( p1.x*s3*fz + s1*p3.z*fx - p1.z*s3*fx - s1*p3.x*fz )
						   -( p1.x*s2*fz + s1*p2.z*fx - p1.z*s2*fx - s1*p2.x*fz );
				}
				else
				/* determinant of 
				p1.x p1.y s1 1           p2x p2y s2       p1x p1y s1       p1x p1y s1
				p2.x p2.y s2 1  =  - det p3x p3y s3 + det p3x p3y s3 - det p2x p2y s2
				p3.x p3.y s3 1            nx ny  0        nx  ny  0        nx  ny  0
				n.x  n.y  0  0
			*/ if( type == 3 ){
					return -( p2.y*s3*fx + s2*p3.x*fy - p2.x*s3*fy - s2*p3.y*fx )
						   +( p1.y*s3*fx + s1*p3.x*fy - p1.x*s3*fy - s1*p3.y*fx )
						   -( p1.y*s2*fx + s1*p2.x*fy - p1.x*s2*fy - s1*p2.y*fx );
				}
				else
				/* determinant of 
				p1.x p1.y p1.z s1              p2x p2y p2z          p1x p1y p1z          p1x p1y p1z
				p2.x p2.y p2.z s2  =  -s1* det p3x p3y p3z + s2*det p3x p3y p3z - s3*det p2x p2y p2z
				p3.x p3.y p3.z s3              nx ny  nz            nx  ny  nz           nx  ny  nz
				n.x  n.y  n.z  0
			*/ if( type == 4 ){
					return -s1*( p2.x*p3.y*fz + p2.y*p3.z*fx + p2.z*p3.x*fy - p2.z*p3.y*fx - p2.y*p3.x*fz - p2.x*p3.z*fy )
						   +s2*( p1.x*p3.y*fz + p1.y*p3.z*fx + p1.z*p3.x*fy - p1.z*p3.y*fx - p1.y*p3.x*fz - p1.x*p3.z*fy )
						   -s3*( p1.x*p2.y*fz + p1.y*p2.z*fx + p1.z*p2.x*fy - p1.z*p2.y*fx - p1.y*p2.x*fz - p1.x*p2.z*fy );
				}
			}
			return 0;
		}
		
		public static function computeNormal( m:HEMesh , f:Face ):Boolean{
			var tri:Triangle3D = f.pv3dFace;
			tri.createNormal()
			
			if( tri.faceNormal.moduloSquared == 0 ){
				f.valid = false;
				return false;
			}
			return true;
		}
		
		public static function GET_AREA_V( p1:Vertex3D , p2:Vertex3D , p3:Vertex3D , scale:Number = 1 ):Number{
			var lambda:Number;
			var	detA:Number = p1.x*p2.y + p2.x*p3.y + p3.x*p1.y - p3.x*p2.y - p2.x*p1.y - p1.x*p3.y;
			var detB:Number = p1.y*p2.z + p2.y*p3.z + p3.y*p1.z - p3.y*p2.z - p2.y*p1.z - p1.y*p3.z;
			var detC:Number = p1.z*p2.x + p2.z*p3.x + p3.z*p1.x - p3.z*p2.x - p2.z*p1.x - p1.z*p3.x;
			lambda = 0.5*Math.sqrt( detA*detA + detB*detB + detC*detC );
			return lambda * scale;
		}
	}
}