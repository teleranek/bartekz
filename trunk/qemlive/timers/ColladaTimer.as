package qemlive.timers
{
	import flash.utils.Timer;

	public class ColladaTimer extends Timer
	{
		public var waitingGeometries:Array;
		public var onFinish:Function;
		public var async:Boolean;
		public var list:XMLList;
		public function ColladaTimer(delay:Number, list:XMLList , async:Boolean , waitingGeometries:Array , onFinish:Function = null )
		{
			this.list = list;
			this.async = async;
			this.waitingGeometries = waitingGeometries;
			this.onFinish = onFinish;
			super(delay, 0 );
		}
		
		public override function get currentCount():int{
			return super.currentCount-1;
		}
		
	}
}