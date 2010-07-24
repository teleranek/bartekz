package qemlive.timers
{
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import qemlive.hedge.HEMesh;
	
	import org.papervision3d.core.proto.GeometryObject3D;

	public class GeometryTimer extends Timer
	{
		public var go3d:GeometryObject3D;
		public var dict:Dictionary;
		public function GeometryTimer(delay:Number, go3d:GeometryObject3D )
		{
			this.go3d = go3d;
			this.dict = new Dictionary();
			super(delay, 0);
		}
		
		public override function get currentCount():int{
			return super.currentCount - 1;
		}
		
	}
}