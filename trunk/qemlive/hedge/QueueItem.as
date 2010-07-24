package qemlive.hedge{
	public class QueueItem{
		public var fidx:int
		public var numNewHEdges:uint;
		
		public function QueueItem( f:int , nnh:uint ){
			fidx = f;
			numNewHEdges = nnh;
		}
	}
}