package qemlive.hedge
{
		/*
	could be wrong
	*/
	internal class Node{
		public var children:Array;
		
		public function isLeaf():Boolean{
			return ( children.length == 1 );
		}
		
		public function child( i:int ):Node{
			return children[ i ];
		}
		
		public function get leaf():Leaf{
			if( isLeaf() ) return children[ 0 ];
			else return null;
		}
		
		public function set leaf( l:Leaf ):void{
			children.splice( 0 );
			children.push( l );
		}
		
		public function Node():void{
			children = new Array();
		}
		
	}
}