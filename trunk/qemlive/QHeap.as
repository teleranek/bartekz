package qemlive
{
	public class QHeap
	{
		public var heap:Array;
		
		// import = value
		// token  = edge pos
		public function QHeap()
		{
			heap = new Array();
		}
		
		private function place( q:Quadric , i:uint ):void
		{
    		heap[ i ] = q;
    		q.pos = i
		}
		
		private function swap( i:uint , j:uint ):void
		{
    		var tmp:Quadric = heap[ i ];

    		place(heap[ j ], i );
    		place( tmp , j);
		}
		
		private function parent( i:uint ):uint{ return (i-1)/2; }
    	private function left( i:uint ):uint { return 2*i+1; }
    	private function right(i:uint):uint { return 2*i+2; }
    	public function get length():uint{ return heap.length; }
		
		private function upheap( i:uint ):void
		{
		    var moving:Quadric = heap[ i ];
		    var index:uint = i;
		    var p:uint = parent(i);
		
		    while( index>0 && moving.value > heap[p].value )
		    {
				place( heap[p] , index);
				index = p;
				p = parent(p);
		    }
		
		    if( index != i ) place(moving, index);
		}
		
		private function downheap( i:uint ):void
		{
		    var moving:Quadric = heap[ i ];
		    var index:uint = i;
		    var l:uint = left(i);
		    var r:uint = right(i);
		    var largest:uint;
		
		    while( l<length )
		    {
				if( r < length && heap[l].value < heap[r].value )
			    	largest = r;
				else 
			    	largest = l;
		
				if( moving.value < heap[largest].value )
				{
				    place( heap[ largest ] , index);
				    index = largest;
				    l = left(index);
				    r = right(index);
				}
				else
				    break;
		    }
		
		    if( index != i )
			place(moving, index);
		}
		
		public function insert( t:Quadric ):void
		{
    		heap.push( t );
    		var i:uint = length - 1;
    		t.pos = i;
    		upheap(i);
		}

		public function update( t:Quadric ):void
		{
			var i:uint = t.pos;
		    if( t.pos == 4294967295 ){ 
		    	trace("updating zombies"); return; }
		    if( t.value>heap[parent(i)].value )
				upheap(i);
		    else
				downheap(i);
		}
		
		public function top():Quadric{
			return heap[ 0 ];
		}
		
		public function extract():Quadric
		{
    		if( length < 1 ) return null;

    		swap(0, length-1);
    		var dead:Quadric = heap.pop();

    		downheap(0);
    		dead.pos = 4294967295;
    		return dead;
		}

		public function remove( t:Quadric ):Quadric
		{
		    if( t.pos == 4294967295 ){ 
		    	return null; 
		    }
		
		    var i:uint = t.pos;
		    if( i == length - 1 ){
		    	heap.pop();
		    	t.pos = 4294967295;
		    } 
		    else{	    
			    swap(i, length-1);
			    heap.pop();
			    t.pos = 4294967295;
			
			    if( heap[i].value < t.value )
					downheap(i);
			    else
					upheap(i);
		    }
		    return t;
		}
		
		public function clear():void{
			heap.splice( 0 );
		}
	}
}