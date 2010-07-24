package qemlive.hedge
{
	
	import org.papervision3d.core.geom.renderables.Vertex3D;
	import org.papervision3d.core.math.Number3D;

	public final class OCTree
	{
		private const maxDataPerNode:int = 50;
		private const maxTreeDepth:int = 10;
		
		public var root:Node;
		public var box:AABB;
		
		public function OCTree( box:AABB )
		{
			this.box = box;
			root = new Node();
			root.leaf = new Leaf();
		}
		
		public function findData( pos:Vertex , maxDist:Number ):Array{
			return new OCTreeIter( this , pos , maxDist ).opApply();
		}
		
		public function addVertex( v:Vertex ):void{
			var node:Node = root;
			var center:Number3D = box.center;
			var size:Number3D = box.size;
			var depth:int = 1;
			
			var idx:int = 0;
			var i:int;
			var newNode:Node;
			var vn3d:Number3D = v.v.toNumber3D();
			
			while( !node.isLeaf() ){
				idx = 0;
				size.x *= 0.5; size.y *= 0.5; size.z *= 0.5;
				
				if( vn3d.x - center.x <= 0 ){ center.x -= size.x }
				else{ center.x += size.x; idx |= 1; }
				
				if( vn3d.y - center.y <= 0 ){ center.y -= size.y }
				else{ center.y += size.y; idx |= 2; }
				
				if( vn3d.z - center.z <= 0 ){ center.z -= size.z }
				else{ center.z += size.z; idx |= 4; }
				
				node = node.child( idx );
				++depth;
			}
			
			if( !node ) throw new Error( "node isnt null!" );
			if( !node.isLeaf() ) throw new Error( "node isnt leaf!");
			
			var leaf:Leaf = node.leaf;
			if( !leaf ) throw new Error( "Leaf is NULL" );
			
			var currentData:Vertex;
			if( ( leaf.data.length + 1 > this.maxDataPerNode ) && ( depth < this.maxTreeDepth ) ){
				
				// init some arrays
				node.children.splice( 0 );
				node.children = new Array( 8 );
				for( i = 0; i < 8; i++ ){
					newNode = new Node();
					newNode.leaf = new Leaf();
					node.children[ i ] = newNode;
				}
				
				for( i = 0; i < leaf.data.length+1; i++ ){
					currentData = ( i == leaf.data.length ? v : leaf.data[ i ] );
					idx = 0;
					
					if( currentData.v.x - center.x > 0 ){ idx |= 1; }
					if( currentData.v.y - center.y > 0 ){ idx |= 2; }
					if( currentData.v.z - center.z > 0 ){ idx |= 4; }
					
					var l:Leaf = node.children[ idx ].leaf;
					if( !l ) throw new Error( "Leaf is NULL" );
					l.add( currentData );
				}
				
				leaf.free();
				leaf = null;				
			}else{
				leaf.add( v );
			}
		}

	}
}