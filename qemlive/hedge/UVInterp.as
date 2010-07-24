package qemlive.hedge
{
	import org.papervision3d.core.math.Number3D;
	import org.papervision3d.core.math.NumberUV;

	internal final class UVInterp
	{
		public var uv:NumberUV;
		public var normal:Number3D;
		public function UVInterp( normal:Number3D , uv:NumberUV )
		{
			this.normal = normal;
			this.uv = uv;
		}
	}
}