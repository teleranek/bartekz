package qemlive.timers
{
	import flash.utils.Timer;
	
	import qemlive.hedge.OCTree;
	
	public class ComputationTimer extends Timer
	{
		public var done:Array;
		public var merged:Boolean;
		public var vhash:OCTree;
		public var maxdist:Number;
		public function ComputationTimer( delay:Number , done:Array  )
		{
			this.done = done;
			merged = false;
			super(delay, 0);
		}
		
		public override function get currentCount():int{
			return super.currentCount - 1;
		}

	}
}