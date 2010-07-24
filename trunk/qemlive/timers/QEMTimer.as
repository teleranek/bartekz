package qemlive.timers
{
	import flash.utils.Timer;
	
	import qemlive.QHeap;

	public class QEMTimer extends Timer
	{
		public var vertexQuadrics:Array;
		public var quadrics:QHeap;
		public var h2e:Array;
		public var facesNum:uint;
		public var accurate:Boolean;
		
		public function QEMTimer(delay:Number , facesNum:uint , accurate:Boolean )
		{
			this.accurate = accurate;
			this.facesNum = facesNum;
			super(delay, 0);
		}
		
		public override function get currentCount():int{
			return super.currentCount - 1;
		}
		
	}
}