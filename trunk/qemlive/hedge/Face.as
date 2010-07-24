package qemlive.hedge{
	import org.papervision3d.core.geom.renderables.Triangle3D;
	import org.papervision3d.core.proto.MaterialObject3D;
	import org.papervision3d.materials.BitmapMaterial;
	import org.papervision3d.materials.special.CompositeMaterial;
	import org.papervision3d.materials.utils.BitmapMaterialTools;
	
	import qemlive.Quadric;
	
	public class Face{
		public var fh:HEdge; // first hedge
		public var fidx:int; // face index in mesh
		public var finitNum:int; // pv3dface index in geometry.faces
		
		public var pv3dFace:Triangle3D;
		
		public var q:Quadric;
		public var valid:Boolean;
		public function Face( fhe:HEdge , fid:int = -1 , finit:int = 0 ){
			fidx = fid;
			finitNum = finit;
			fh = fhe;
			valid = true;
		}
		
		public function updateMatrices():void{
			if( pv3dFace.material is BitmapMaterial ){
				BitmapMaterial( pv3dFace.material ).uvMatrices[ pv3dFace.renderCommand ] = null;
			}else if( pv3dFace.material is CompositeMaterial ){
				var mat:MaterialObject3D;
				for each( mat in CompositeMaterial(pv3dFace.material).materials ){
					if( mat is BitmapMaterial ){
						BitmapMaterial( mat ).uvMatrices[ pv3dFace.renderCommand ] = null;
					}
				}
			}
			
		}
	}
}