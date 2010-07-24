package qemlive.hedge{

	public class HEdge{
		
		public var nfhi:HEdge; // next hedge in face
		public var nehi:HEdge; // next hedge in edge
		public var nvhi:int; // next vertex hedge
		public var eidx:int; // index of edge in mesh. Automatically set by HEMesh's addHEdge
		public var face:Face;
		public var v:Vertex; // set in constructor
		public var opp:uint; // opposite = {0,1}
		
		public function HEdge( v:Vertex = null ){
			this.v = v;
			eidx = -1;
			nvhi = -1;
		}
		
		/*
		public function nextFaceHEdge():HEdge{
			return nfhi;
		}*/
		//public function nextEdgeHEdge():
		
		public function isNextEdgeHEdgeOpposite():Boolean{
			return nehi.opp!=opp;
		}
		
		public function setNextEdgeHEdgeOpposite( v:Boolean ):void{
			if( v ) nehi.opp = ~opp;
			else nehi.opp = opp;
		}
		
		public function toString():String{
			return "Shit";
		}
		
	}
}