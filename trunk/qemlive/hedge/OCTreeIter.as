package qemlive.hedge
{
	import org.papervision3d.core.math.Number3D;
	
	public final class OCTreeIter{
		public var tree:OCTree;
		public var pos:Vertex;
		public var maxDist:Number;
		
		public function OCTreeIter( t:OCTree , p:Vertex , d:Number ):void{
			this.tree = t;
			this.pos = p;
			this.maxDist = d;
		}
		
		public function opApply():Array{
			var maxDist2:Number = maxDist*maxDist;
			const stackSize:int = 64;
			var stack:Array = new Array( );
			var item:StackItem;
			var leaf:Leaf; 
			var d:Vertex;
			var dist2:Number;
			var res:int , c:int , x:int , y:int , z:int;
			var fnd:Array = new Array();
			
			stack.push( new StackItem( tree.root , tree.box.center , tree.box.size ) );			
			while( stack.length ){
				item = stack.pop();
				if( item.node.isLeaf() ){
					leaf = item.node.leaf;
					for each( d in leaf.data ){
						// could be kinda slow
						dist2 = Number3D.sub( d.v.toNumber3D() , pos.v.toNumber3D() ).moduloSquared;
						if( dist2 <= maxDist2 ){
							fnd.push( d );
						}
					}
				}else{
					//off = Number3D.sub( pos.v.toNumber3D() , item.center );
					var checkMasks:Array = [ true,true, true,true, 
											 true,true, true,true ];
					var cell:Array = [ pos.v.x - item.center.x , pos.v.y - item.center.y , pos.v.z - item.center.z ];
					// we could unroll these fors
					for( c = 0; c < 3; c++ ){
					// ###############	
						if( cell[ c ] > maxDist ){
							for( x = 0; x < 2; x++ ){
								if( c != 0 || 0 == x ) for ( y = 0; y < 2; ++y) {
   									if (c != 1 || 0 == y) for ( z = 0; z < 2; ++z) {
										if (c != 2 || 0 == z) {
											checkMasks[ x + 2 * y + 4 * z ] = false;
										}
   									}
   								}
   							}
						}
						
						if( cell[ c ] < -maxDist ){
							for( x = 0; x < 2; x++ ){
								if( c != 0 || 1 == x ) for ( y = 0; y < 2; ++y) {
   									if (c != 1 || 1 == y) for ( z = 0; z < 2; ++z) {
										if (c != 2 || 1 == z) {
											checkMasks[ x + 2 * y + 4 * z ] = false;
										}
   									}
   								}
   							}
						}
					// #############	
					}
					
					for( c = 0; c < 8; c++ ){
						if( !checkMasks[ c ] ) continue;
						var newSize:Number3D = new Number3D( item.size.x*.5 , item.size.y*.5 , item.size.z*.5 );
						var newCenter:Number3D = new Number3D();
						
						if (0 == (c & 1)) newCenter.x = item.center.x - newSize.x;
						else newCenter.x = item.center.x + newSize.x;
						if (0 == (c & 2)) newCenter.y = item.center.y - newSize.y;
						else newCenter.y = item.center.y + newSize.y;
						if (0 == (c & 4)) newCenter.z = item.center.z - newSize.z;
						else newCenter.z = item.center.z + newSize.z;
						
						stack.push( new StackItem( item.node.child( c ) , newCenter, newSize ) );
					}
				}
			}
			return fnd;							
		}
		
	}
}