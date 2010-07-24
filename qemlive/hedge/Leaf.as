package qemlive.hedge
{
	internal class Leaf{
			public var data:Array;
			public function add( v:Vertex ):void{
				data.push( v );
			}
			public function get len():int{
				return data.length;
			}
			public function free():void{
				// cant really free it...
				data = null;
				data = new Array();
				return;
			}
			public function Leaf():void{
				data = new Array();
			}
		}
}