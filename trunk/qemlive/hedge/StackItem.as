package qemlive.hedge
{
	import org.papervision3d.core.math.Number3D;

	internal class StackItem{
		public var node:Node;
		public var center:Number3D;
		public var size:Number3D;
		public function StackItem( n:Node , c:Number3D , s:Number3D ):void{
			this.node = n; this.center = c; this.size = s;
		}
	}
}