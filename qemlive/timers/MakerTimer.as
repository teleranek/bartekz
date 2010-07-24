package qemlive.timers
{
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import org.papervision3d.core.geom.Lines3D;
	import org.papervision3d.core.geom.TriangleMesh3D;
	import org.papervision3d.core.proto.MaterialObject3D;
	
	import qemlive.hedge.HEMesh;
	
	public class MakerTimer extends Timer
	{
		public var mats:Dictionary;
		public var newDo3D:TriangleMesh3D;
		public var mesh:HEMesh;
		public var mat:MaterialObject3D;
		public var onFinish:Function;
		
		public function MakerTimer(delay:Number , mat:MaterialObject3D , mesh:HEMesh , onFinish:Function )
		{
			this.mat = mat;
			this.mesh = mesh;
			this.onFinish = onFinish;
			mats = new Dictionary();
			newDo3D = new TriangleMesh3D( mat , new Array() , new Array() , null );
			super(delay, 0);
		}
		
		public override function get currentCount():int{
			return super.currentCount-1;
		}
	}
}