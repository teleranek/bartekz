package qemlive.hedge{
	public class OHEdge{
		public var eidx:int;
		public var opp:Boolean;
		public var nhi:int;
		public var nvi:Vertex;
		public var v0:Vertex;
		public var v1:Vertex;
		
		public function OHEdge(){
			eidx = -1;
			nhi = -1;
		}
	}
}