/*
[]deleting vertices
[]deleting faces
[]decimate function -> more collapses perhaps.
----------------------
[]undecimate function
*/
package qemlive
{	
	import flash.events.TimerEvent;
	import flash.text.TextField;
	import flash.utils.Dictionary;
	
	import org.papervision3d.core.data.UserData;
	import org.papervision3d.core.math.Number3D;
	import org.papervision3d.core.math.NumberUV;
	import org.papervision3d.core.proto.MaterialObject3D;
	import org.papervision3d.materials.BitmapMaterial;
	import org.papervision3d.materials.special.CompositeMaterial;
	import org.papervision3d.objects.DisplayObject3D;
	
	import qemlive.hedge.DO3DMaker;
	import qemlive.hedge.Face;
	import qemlive.hedge.HEMesh;
	import qemlive.hedge.HEdge;
	import qemlive.hedge.Vertex;
	import qemlive.hedge.Vertex2;
	import qemlive.timers.QEMTimer;
	
	public class TeleQEM
	{
		public static var progressInfo:TextField = null;
		
		private var mesh:HEMesh;
		private var currentMaterial:MaterialObject3D;
		private var qtime:QEMTimer;
		private var initialised:Boolean;
		private var _busy:Boolean;
		/*
		attributes = 2 -> we interpolate only texture coords u,v
		attributes = 5 -> we interpolate normals and uv's
		attributes = 0 -> we dont interpolate any additional attributes
		*/
		private var attributes:uint; 
		private var onFinishQEM:Function;
		public static const COMPLETE_DECIMATION:String = "WORK_COMPLETED";
		
		public static const INTERPOLATE_UV:uint = 2;
		public static const INTERPOLATE_UV_AND_NORMALS:uint = 5;
		public static const INTERPOLATE_NOTHING:uint = 0;
		
		private const AREASCALE:Number = 0.1;//0.0006;
		// how much to scale area of boundary edges.
		private const BOUNDSCALE:Number = 100;
		
		// number of invalid edges to punish algorithm. 0 == turned off
		private const VALIDITY_THRESHOLD:Number = 3; 
		private const VALIDITY_RATIO:Number = 5;
		
		// threshold for detecting invalid minimizations
		private const MINIMIZATION_VALIDITY:Number = 5.0;
		
		// number 0-1 which indicates how sharp edged triangles are punished. 0 = off
		private const COMPACTNESS_THRESHOLD:Number = 0.2; //0.1
		private const COMPACTNESS_RATIO:Number = 5;
		private const SHARP_EDGE_THRESHOLD:Number = 0.2;
		private const SHARP_EDGE_RATIO:Number = 5;
		
		private const MAT_DISC_RATIO:Number = 0;//10000000;
		
		private static const TIMERDELAY:Number = 1; // delay after every timer cycle.
		public static const TIMERCOUNT_LIGHT:Number = 1000; // timer cycles for low demanding tasks
		public static const TIMERCOUNT_HARD:Number = 10; // timer cycles for high demanding tasx;
		
		private const FLOAT_ERROR:Number = 1e-12;
		
		public var removeSharedVertices:Boolean = true;
		// VARS ON CONSTS
		public var areaScale:Number = AREASCALE;
		public var boundScale:Number = BOUNDSCALE;
		public var validityThreshold:Number = VALIDITY_THRESHOLD;
		public var validityRatio:Number = VALIDITY_RATIO;
		public var compactnessThreshold:Number = COMPACTNESS_THRESHOLD;
		public var compactnessRatio:Number = COMPACTNESS_RATIO;
		public var sharpEdgeThreshold:Number = SHARP_EDGE_THRESHOLD;
		public var sharpEdgeRatio:Number = SHARP_EDGE_RATIO;
		public var matDiscRatio:Number = MAT_DISC_RATIO;
		public var minimizationValidity:Number = MINIMIZATION_VALIDITY;
		
		// remove unnecessary quadrix
		private const REMOVE_INVALIDS:Boolean = true; // <- in fact, this speeds up decimation process.
		private var states:Array;
		
		public var DEBUG_OUTPUT:Array = null;
		private const DEL_POS:uint = 4294967295;
		
		public function TeleQEM( m:HEMesh )
		{
			mesh = m;
			_busy = false;
			initialised = false;
		}
		
		
		/* ########################################################################
		 * #                           SiMpLiFy                                   #
		 * ########################################################################
		 * [v] boundary constraints - penalties - normals check
		 * [v] validity check after collapse +
		 * [v] + consistency checks
		   [] debug above
		   [] get rid of numbers3d from above
		 * [v] discontinuities
		 * [x] timer func
		 * [v] accuracy
		   [] debug above
		 * [] !!debug uvs and normals!1:
		      whats wrong: uvs are in vertices, but the same vertex may have two different u's and v's
		      fix fromObject3D
		   [] count determinants with recursive formula rather than ..
		   [] fix heap with that pesky val=-val. 
		   [x] DEBUG CUBE 3x3x3 => seems that every edge gets quadric=0. WRONG
		   [x] wrong recomputing for inaccurate mode
		   [x] bug: we must merge same vertices
		   [x] lambda wrong for uv's - they gets scaled down 2 much with lambda eq 1
		 */
		
		// array which maps quadric to edge num
		public var h2e:Array;
		// quadrix heap
		private var quadrics:QHeap;
		// quadrix 4 vertices as sums of adj facez
		private var vertexQuadrics:Array;
		
		public function init( onFinish:Function , attributes:uint ):void{
			quadrics = new QHeap( );
			onFinishQEM = onFinish;
			h2e = new Array( mesh.numHEdges );
			vertexQuadrics = new Array();
			
			if( (attributes != TeleQEM.INTERPOLATE_NOTHING)&&
				(attributes != TeleQEM.INTERPOLATE_UV)&&
				(attributes != TeleQEM.INTERPOLATE_UV_AND_NORMALS ) ){ trace("Bad arguments for newqem func"); return; }
			this.attributes = attributes;
			
			qtime = new QEMTimer( TeleQEM.TIMERDELAY , 0 , false );
			qtime.addEventListener( TimerEvent.TIMER , collectFaceQuadrics );
			qtime.start();
		}
		
		public function newqem( facesNum:uint , onFinish:Function , accurate:Boolean = true ):void{
			
			this.onFinishQEM = onFinish;
			if( !initialised ) return;
			if( _busy ){ // we are decimating right now
				qtime.stop();
				
			}
			
			_busy = true;
			
			qtime = new QEMTimer( TeleQEM.TIMERDELAY , facesNum , accurate );
			if( mesh.numFaces - mesh.removedFacesNum > facesNum )
				qtime.addEventListener( TimerEvent.TIMER , decimateTimerListener );
			else qtime.addEventListener( TimerEvent.TIMER , undecimateTimerListener );
			qtime.start();
			
			
			/*
			DELETE EDGES
			*/
			/*
			penalties for quadrics[ quadric num ]: 
				1) degree
					max( v1 neghbors,v2 neighbors ) > something: penalty
				2) validity v1,vnew:
					every face adj v1:
					k = v1, x = nfhi , y = nfhi,nfhi
				3) compactness
			*/
		}
		
		private function undecimateTimerListener( evt:TimerEvent ):void{
			var time:QEMTimer = ((QEMTimer)(evt.target));
			var i:uint;
			
			if( progressInfo ) progressInfo.text = "Undecimating, faces: " + String( mesh.numFaces - mesh.removedFacesNum );
			for( i = time.currentCount*TeleQEM.TIMERCOUNT_HARD; 
				( i < (time.currentCount + 1)*TeleQEM.TIMERCOUNT_HARD ) && ( mesh.numFaces - mesh.removedFacesNum < time.facesNum ); 
				i++ )
			{				
				uncollapse();
			}
			
			if( mesh.numFaces - mesh.removedFacesNum >= time.facesNum ){
				time.stop();
				_busy = false;
				onFinishQEM();
			}
		}
		
		private function decimateTimerListener( evt:TimerEvent ):void{
			var time:QEMTimer = ((QEMTimer)(evt.target));
			var i:uint;
			
			if( progressInfo ) progressInfo.text = "Decimating, faces: " + String( mesh.numFaces - mesh.removedFacesNum );
			for( i = time.currentCount*TeleQEM.TIMERCOUNT_HARD; 
			   ( i < (time.currentCount + 1)*TeleQEM.TIMERCOUNT_HARD ) && ( mesh.numFaces - mesh.removedFacesNum > time.facesNum ); 
				 i++ )
			{				
				if( !decimate( time.accurate ) ) break;
			}
			
			if( mesh.numFaces - mesh.removedFacesNum <= time.facesNum ){
				time.stop();
				_busy = false;
				onFinishQEM();
			}
		}
	
		// maybe make this inline.
		public function decimate( accurate:Boolean ):Boolean{
			var h:HEdge;
			var cur:HEdge;
			var val:Quadric;
			var vi:uint , updated:uint;
			var v:Vertex;
			var edge:uint;
			var val0:Quadric;
			
			val = quadrics.extract();
			
			if( !val ) return false;
			vi = mesh.hedge( val.param ).nfhi.v.vi;
			updated =  mesh.hedge( val.param ).v.vi;
			
			// anomalyz - occur because we didnt remove some quadrics- due to gain in sp33d
			if( mesh.removedHEdges && mesh.removedHEdges[ val.param ] ){
				//trace("removed param");
				return true;
			}
			if( mesh.removedVertices && mesh.removedVertices[ val.v.vi ] ){
				//trace( "mergin to removed" );
				return true;
			}
			if( (val.v.vi != updated ) && ( val.v.vi != vi ) ){
				return true;
			}
			if( !mesh.vertices[ updated ] || !mesh.vertices[ vi ] || ( mesh.removedVertices && ( mesh.removedVertices[ updated ] || mesh.removedVertices[ vi ] ) ))
				return true;
			
			if( vi == updated ){
				// shouldnt occur. 
				// should remove this face
				//trace("zero edge");
				return true;
			}
			
			if( !collapse( val.param , val.v ) ) return true; // == continue
			if( mesh.vertices[ updated ].edge == null ) return true;
			
			/*
			for ( var i:int = 0; i < quadrics.heap.length; i++  ){
				if( mesh.removedVertices && mesh.removedVertices[ quadrics.heap[i].v.vi ] ){
					trace("this one removed:" + String( quadrics.heap[i].v.vi ) );
					//quadrics.heap[i].v.vi = updated;
				}
			}*/
			
			// vertex deleted
			cur = h = mesh.vertices[ updated ].edge;
			
			// if accurate:
			if( attributes ) val0 = getQuadricForHEdgeVertex( h );
			do{
				val = h2e[ cur.eidx ];
				/*
				if accurate:*/
				if( attributes ){
					val.copy( val0 );
					val.add( getQuadricForHEdgeVertex( cur.nfhi  ) );
				}else{
				    val.copy( vertexQuadrics[ updated ] );
					val.add( vertexQuadrics[ cur.nfhi.v.vi ] );
				}
				getOptimum( val , cur.v , cur.nfhi.v );
				setPenalties( val , cur );
				//val.value = -val.value;
				quadrics.update( val );
				
				cur = mesh.hedge( cur.nvhi );
			}while( cur != h );
			
			
			/*
			trace("----- post2 -----");
			for each( var q:Quadric in quadrics.heap ){
				if( mesh.removedVertices[ q.v.vi ] ){
					trace("quadric with invalid vertex:" + String( q.v.vi ) + " - " + String(q.param) + " (" + String(q.pos) + ")" );
				}
			}*/
			
			return true;
		}
		
//		***********************************************************
//		puts state of specified hedge neighborhood into a queue
//			consists of saveVertex func and pushState func
//		***********************************************************
		private function saveVertex( newstate:Object , hinit:HEdge ):void{
			var h:HEdge = hinit;
			var quad:Quadric;
			if( !newstate.vertices[ h.v.vi ] ){
				
				do{
					if( !newstate.vertices[ h.v.vi ]) newstate.vertices[ h.v.vi ] = { idx:h.v.vi , hedge:h.v.edge.eidx , v3d:h.v.v , v3dval:h.v.v.clone() };
					if( !newstate.vquadrix[ h.v.vi ]) newstate.vquadrix[ h.v.vi ] = { idx:h.v.vi , quadric:Quadric.COPY( vertexQuadrics[ h.v.vi ] ) , 
						param:Quadric(vertexQuadrics[ h.v.vi ]).param , 
						value:Quadric(vertexQuadrics[ h.v.vi ]).value };
					if( !newstate.hedges[ h.eidx ] ) newstate.hedges[ h.eidx ] = { 
						idx:h.eidx , nvhi:h.nvhi , nehi:h.nehi.eidx , 
							face:h.face.fidx , nfhi:h.nfhi.eidx , opp:h.opp , vert:h.v.vi 
					};
					if( !newstate.faces[ h.face.fidx ] ) newstate.faces[ h.face.fidx ] = {
						idx:h.face.fidx , hedge:h.face.fh.eidx , 
							uv0u:h.face.pv3dFace.uv0.u , uv0v:h.face.pv3dFace.uv0.v , 
							uv1u:h.face.pv3dFace.uv1.u , uv1v:h.face.pv3dFace.uv1.v , 
							uv2u:h.face.pv3dFace.uv2.u , uv2v:h.face.pv3dFace.uv2.v ,
							v0:h.face.pv3dFace.v0 , v1:h.face.pv3dFace.v1 , v2:h.face.pv3dFace.v2 , 
							nx:h.face.pv3dFace.faceNormal.x , ny:h.face.pv3dFace.faceNormal.y , nz:h.face.pv3dFace.faceNormal.z
					};
					
					if( !newstate.h2es[ h.eidx ] ){
						quad = Quadric.COPY( h2e[ h.eidx]  );
						quad.value = Quadric( h2e[ h.eidx ] ).value;
						quad.v     = new Vertex2();
						quad.param = Quadric( h2e[ h.eidx ] ).param;
						Vertex2.COPY( quad.v , Quadric( h2e[ h.eidx ] ).v );
						quad.v.vi = Quadric( h2e[ h.eidx ] ).v.vi;
						newstate.h2es[ h.eidx ] = { idx:h.eidx , quadric:h2e[ h.eidx ] , quadval:quad };
						if( (h2e[ h.eidx ].pos == 4294967295)&&(newstate.quadric.param != h2e[h.eidx].param) ){ trace("saving deleted"); }
					} 

					h = mesh.hedge( h.nvhi );
				}while( h != hinit );
			}
		}
		private function pushState( hinit:HEdge ):void{
			var h:HEdge = hinit;
			var cur:HEdge;
			var quad:Quadric;
			var qquad:Quadric;
			var newstate:Object = { hedges:new Array() , faces:new Array() , vertices:new Array() , 
									h2es:new Array() , quadric:h2e[hinit.eidx] , quadricValue:(quad=Quadric.COPY(qquad = h2e[hinit.eidx]) ) , vquadrix:new Array() };
			
			if( !states ) states = new Array();
			
			quad.param = qquad.param;
			quad.value = qquad.value;
			quad.v     = new Vertex2();
			Vertex2.COPY( quad.v , qquad.v );
			quad.v.vi = qquad.v.vi;
			// save a star of vertices around an edge
			saveVertex( newstate , h );
			do{
				saveVertex( newstate , h.nfhi );
				h = mesh.hedge( h.nvhi );
			}while( h != hinit );
			
			h = hinit.nfhi;
			do{
				saveVertex( newstate , h.nfhi );
				h = mesh.hedge( h.nvhi );
			}while( h != hinit.nfhi );
			states.push( newstate );
		}
		
		// pops last remembered state
		private function popState( ):void{
			// first restore faces vertices and hedges
			var state:Object = states.pop();
			var h:HEdge;
			var f:Face;
			var v:Vertex;var o:Object;
			if( !state ) return;
			
			
			for each( o in state.vertices ){
				v = mesh.vertices[ o.idx ];
				v.vi = o.idx;
				v.edge = mesh.hedge( o.hedge );
				v.v = o.v3d;
				v.v.extra = v;
				if( mesh.removedVertices[ v.vi ] ){
					//v.vinitNum = mesh.geometry.vertices.length;
					//mesh.geometry.vertices.push( v.v );
					/*
					v.v.x = o.v3dval.x;	v.v.y = o.v3dval.y;	v.v.z = o.v3dval.z;
					v.v.normal = o.v3dval.normal;
					v.v.vertex3DInstance = o.v3dval.vertex3DInstance;
					v.v.connectedFaces = new Dictionary();*/
					mesh.removedVertices[ v.vi ] = null;
				} 
			}
			for each( o in state.hedges ){
				h = mesh.hedge( o.idx );
				h.eidx = o.idx;
				h.nvhi = o.nvhi;
				h.nehi = mesh.hedge( o.nehi );
				h.face = mesh.face( o.face );
				h.nfhi = mesh.hedge( o.nfhi );
				h.opp = o.opp;
				h.v = mesh.vertices[ o.vert ];
				if( mesh.removedHEdges[ h.eidx ] ) mesh.removedHEdges[ h.eidx ] = null;
			}
			for each( o in state.faces ){
				f = mesh.face( o.idx );
				
				if( mesh.removedFaces[ o.idx ] ){
					f.finitNum = mesh.geometry.faces.length;
					mesh.geometry.faces.push( f.pv3dFace );
					mesh.removedFaces[ o.idx ] = null;
					mesh.removedFacesNum--;
				}
				
				f.pv3dFace.v0 = f.pv3dFace.vertices[0] = o.v0;
				f.pv3dFace.v1 = f.pv3dFace.vertices[1] = o.v1;
				f.pv3dFace.v2 = f.pv3dFace.vertices[2] = o.v2;
				
				f.pv3dFace.uv = [ new NumberUV(o.uv0u,o.uv0v) , new NumberUV(o.uv1u,o.uv1v), new NumberUV(o.uv2u,o.uv2v) ];
								
				f.pv3dFace.faceNormal.x = o.nx;
				f.pv3dFace.faceNormal.y = o.ny;
				f.pv3dFace.faceNormal.z = o.nz;
				
				f.updateMatrices();
			}
			
			// now restore quadrix
			for each( o in state.vquadrix ){
				Quadric(vertexQuadrics[ o.idx ]).copy( o.quadric );
				Quadric(vertexQuadrics[ o.idx ]).param = o.param;
				Quadric(vertexQuadrics[ o.idx ]).value = o.value;
			}
			
			Quadric(state.quadric).copy(state.quadricValue);
			state.quadric.param = state.quadricValue.param;
			state.quadric.v = state.quadricValue.v;
			state.quadric.value = state.quadricValue.value;
			quadrics.insert(state.quadric);
			
			for each( o in state.h2es ){
				h2e[ o.idx ] = o.quadric;
				o.quadric.copy( o.quadval );
				o.quadric.param = o.quadval.param;
				o.quadric.v = o.quadval.v;
				o.quadric.value = o.quadval.value;
				if( REMOVE_INVALIDS && (o.quadric.pos == DEL_POS) ){
					quadrics.insert( o.quadric );
				}
			}
			
			//checkDebugErrors("uncollapse");
		}
		
		// should reverse last collapse opertn
		public function uncollapse():void{
			popState();
		}
		
		private function getQuadricForHEdgeVertex( h:HEdge ):Quadric{
			// go thru all faces adj to h.v
			var faces:Array = new Array();
			var cur:HEdge = h;
			var ret:Quadric = Quadric.ZERO( attributes );
			
			do{
				if( !faces[ cur.face.fidx ] ){
					faces[ cur.face.fidx ] = true; 
					ret.add( Quadric.fromFace( cur.face , attributes , areaScale ) );
				}
				cur = mesh.hedge( cur.nvhi );
			}while( cur != h );
			return ret;
		}
		
		private function collectFaceQuadrics( evt:TimerEvent ):void{
			var f:Face;
			var a:uint, b:uint , c:uint;
			var time:QEMTimer = ((QEMTimer)(evt.target));
			
			if( progressInfo ) progressInfo.text = "Collecting faces: " + String( mesh.numFaces - TeleQEM.TIMERCOUNT_LIGHT*time.currentCount );
			for( var i:uint = time.currentCount*TeleQEM.TIMERCOUNT_LIGHT; 
					 ( i < (time.currentCount + 1)*TeleQEM.TIMERCOUNT_LIGHT ) && ( i < mesh.numFaces ); 
					 i++ )
			{
				f=mesh.face(i);
				f.q = Quadric.fromFace( f , attributes , areaScale );
				/*if( f.q.compute( f.q.minimize() ) < 0 ){
					trace("bad mini??");
				}*/
				if( !vertexQuadrics[ a = f.fh.v.vi ] ) vertexQuadrics[ a ] = Quadric.ZERO( attributes );
				if( !vertexQuadrics[ b = f.fh.nfhi.v.vi ] ) vertexQuadrics[ b ] = Quadric.ZERO( attributes );
				if( !vertexQuadrics[ c = f.fh.nfhi.nfhi.v.vi ] ) vertexQuadrics[ c ] = Quadric.ZERO( attributes );
				vertexQuadrics[ a ].add( f.q );
				vertexQuadrics[ b ].add( f.q );
				vertexQuadrics[ c ].add( f.q );
				
				// discontinuities
				if( boundScale ) fixDisconts( f );
			}
			
			if( i == mesh.numFaces ){
				time.reset();
				time.removeEventListener( TimerEvent.TIMER , collectFaceQuadrics );
				time.addEventListener( TimerEvent.TIMER , collectEdgeQuadrics );
				time.start();
			}
		}
		
		/*
			2. add Quadrics to corresponding HEdges, create an array of quadrics sorted by cost
	   		edgeQuadrics[ i ].param points to corresponding HEdge.
		*/
		private function collectEdgeQuadrics( evt:TimerEvent ):void{
			var cur:HEdge;
			var val:Quadric;
			var neighb:uint;
			var time:QEMTimer = ((QEMTimer)(evt.target));
			var h:HEdge;
			
			if( progressInfo ) progressInfo.text = "Collecting edges: " + String( mesh.numHEdges - TeleQEM.TIMERCOUNT_LIGHT*time.currentCount );
			for( var i:uint = time.currentCount*TeleQEM.TIMERCOUNT_LIGHT; 
					 ( i < (time.currentCount + 1)*TeleQEM.TIMERCOUNT_LIGHT ) && ( i < mesh.numHEdges ); 
					 i++ )
			{
				h=mesh.hedge(i); 
				if( h2e[ h.eidx ] != null ) continue;
				
				val = Quadric.ZERO( attributes );
				
				cur = h;
				neighb = 0;
				do{
					neighb++;
					h2e[ cur.eidx ] = val;
					cur = cur.nehi;
				}while( cur != h );
				
				val.add( vertexQuadrics[ h.v.vi ] );
				val.add( vertexQuadrics[ h.nfhi.v.vi ] );
				val.param = h.eidx;
				
				getOptimum( val , h.v , h.nfhi.v );
				
				setPenalties( val , h );
				quadrics.insert( val );
				//val.value = -val.value;
			}
			
			if( i == mesh.numHEdges ){
				time.reset();
				initialised = true;
				time.removeEventListener( TimerEvent.TIMER , collectEdgeQuadrics );
				onFinishQEM();
			}
		}
		
		private function validQuadric( q:Quadric ):Boolean{
			/*
			alfa*min( dist( vi, v ) ) < max( dist( vi , vi+1 ) ) 
			*/
			var min:Number = Number.POSITIVE_INFINITY;
			var curMin:Number;
			var max:Number = Number.NEGATIVE_INFINITY;
			var curMax:Number;
			var h:HEdge = mesh.hedge( q.param );
			var cur:HEdge = h;
			
			do{
				curMin = Math.min( Vertex.SUBLEN( cur.v , q.v ) , 
								   Vertex.SUBLEN( cur.nfhi.v , q.v ) ,
								   Vertex.SUBLEN( cur.nfhi.nfhi.v , q.v ) );
				if( min > curMin ) min = curMin;
				
				curMax = Math.max( Vertex.SUBLEN( cur.v , cur.nfhi.v ) , 
								   Vertex.SUBLEN( cur.nfhi.v , cur.nfhi.nfhi.v ) ,
								   Vertex.SUBLEN( cur.nfhi.nfhi.v , cur.v ) );
				if( max < curMax ) max = curMax;
				
				cur = cur.nehi;
			}while( cur != h );
			
			return minimizationValidity*min < max;
		}
		
		private function fixDisconts( f:Face ):void{
			var qdisc:Quadric = Quadric.ZERO( attributes );
			var cur:HEdge = f.fh;
			var cur2:HEdge;
			var diff:Dictionary;
			var matNum:int;
			var kriss:Number3D;
			var kross:Number3D;
			var cross:Number;
			
			
			do{
				// border
				if( cur.nehi == cur ){
					applyDiscont( cur );
				}else{
				// sth else
					if( cur == cur.nehi.nehi){
						kriss = cur.face.pv3dFace.faceNormal;
						kross = cur.nehi.face.pv3dFace.faceNormal;
					}
					if( false && (cur == cur.nehi.nehi) && 
					    ( (cross = Number3D.sub( kriss , kross ).moduloSquared ) >= 3 )
						/*Math.asin( Number3D.cross( kriss , kross ).modulo/kriss.modulo/kross.modulo*/  
					){
					// if angle between normals exceeds 90
						applyDiscont( cur )
					}else{
						
						/*
						let's not handle different materials, but UV's instead
						cur2 = cur;
						matNum = 0;
						diff = new Dictionary();
						do{
							if( cur2.face.pv3dFace.material && ( !diff[ cur2.face.pv3dFace.material ] ) ){
								if( ++matNum == 2 ) break;
								diff[ cur2.face.pv3dFace.material ] = true;
							}
							cur2 = cur2.nehi;
						}while( cur2 != cur );
						// edge divides different materials = discontinuity
						if( matNum == 2 ){
							applyDiscont( cur );
						}
						*/
					}
				}
				
				cur = cur.nfhi;
			}while( cur != f.fh );
		}
		
		private function applyDiscont( h:HEdge ):void{
			var q:Quadric;
			// compute: 
			// C , b , c , g
			//var p1:Vertex = f.fh.v;
			//var p2:Vertex = f.fh.nfhi.v;
			//var p3:Vertex = f.fh.nfhi.nfhi.v;
			// or: Q( I , -p , p*p );
			var e:Number3D = new Number3D( h.nfhi.v.v.x - h.v.v.x, h.nfhi.v.v.y - h.v.v.y , h.nfhi.v.v.z - h.v.v.z );
			var n:Number3D = h.face.pv3dFace.faceNormal;
			var n2:Number3D = Number3D.cross( e , n );
			n2.normalize();
			
			var C:Array = new Array( 6 );
			C[ 0 ] = n2.x*n2.x;
			C[ 1 ] = n2.x*n2.y;
			C[ 2 ] = n2.x*n2.z;
			C[ 3 ] = n2.y*n2.y;
			C[ 4 ] = n2.y*n2.z;
			C[ 5 ] = n2.z*n2.z;
			
			var sum:Number = 0;
			var b:Array = new Array( attributes + 3 );
			var g:Array = new Array( attributes );
			b[0] = -n2.x*h.v.v.x;
			b[1] = -n2.y*h.v.v.y;
			b[2] = -n2.z*h.v.v.z;
			for each( var num:Number in b ){ sum += num*num; }
			for( var i:int = 0; i < attributes; i++ ) g[ i ] = new Number3D( );
			
			vertexQuadrics[ h.v.vi ].add( q = new Quadric( C , b , sum , g, areaScale*e.moduloSquared*e.moduloSquared*boundScale , 1 ) );
			vertexQuadrics[ h.nfhi.v.vi ].add( q );
			// n2*h.nfhi
		}
		
		private function getOptimum( val:Quadric , v1:Vertex , v2:Vertex ):void{
			var val1:Number;
			var _v1:Vertex2 = Vertex2.fromVertex( v1 , mesh , attributes!=0 );
			var _v2:Vertex2 = Vertex2.fromVertex( v2 , mesh , attributes!=0 );
			val1 = val.compute( _v1 );
			val.compute( _v2 );
			val.v = new Vertex2();
			if( val1 < val.value ){ // NOTE: SIGNS
				val.value = val1;
				if( mesh.removedVertices && mesh.removedVertices[ v1.vi ] ){ trace("setting to removed!"); }
				val.v.vi = v1.vi;
			}else{
				if( mesh.removedVertices && mesh.removedVertices[ v2.vi ] ){ trace("setting to removed!"); }
				val.v.vi = v2.vi;
			}
		}
		
		/*
		collapse doing some QEM-specific tasks
		*/
		public function collapse( hi:uint , newv:Vertex2 ):Boolean{
			var h:HEdge; 
			var cnt635:int = 0;
			if( !mesh.hedge(hi) ){ trace("edge removed 0"); return false; }
			else if( mesh.removedHEdges && ( mesh.removedHEdges[ hi ] ) ){
				trace( "edge removed 1" ); return false;
			}
			
			if( !mesh.removedHEdges ) mesh.removedHEdges = new Array();
			if( !mesh.removedFaces) mesh.removedFaces = new Array();
			var nowRemovedHEdges:Array = new Array();
			var hinit:HEdge = mesh.hedge( hi );
			h = hinit;
			
			var cur:HEdge, cur2:HEdge;
			
			pushState( hinit );
			
			mesh.mergeVerticesQEM( hinit , newv);
			
			// delete references 2 deleted vertex
			deleteZeroEdges( h, nowRemovedHEdges );
			deleteZeroEdges( h.nfhi, nowRemovedHEdges );
			
			if( REMOVE_INVALIDS ){
				var nehi:int;
				for each( h in nowRemovedHEdges ){
					nehi = findNehi( h );
					if( nehi < 0 ){
						if( Quadric( h2e[ h.eidx ] ).pos != DEL_POS ){
							quadrics.remove( Quadric( h2e[ h.eidx ] ) );
						}
						h2e[ h.eidx ] = null;
					}
					if( mesh.removedHEdges[ nehi ] ){
						trace("WTF?");
					}
				}
			}
			// merge nvhi's to newv ( adjacent to v0e and v1e )
			correctNVHI( [ hinit , hinit.nfhi ] );
			
			// delete references to unchanged edge 
			//for each( var v2:HEdge in v2s ) correctNVHI( [ v2.v.edge ] );
			
			for each( h in nowRemovedHEdges ){
				correctNVHI( [ h.v.edge ] );
				if( h.v.edge && ( !mesh.hedge(h.v.edge.eidx) || mesh.removedHEdges[ h.v.edge.eidx ] ) ) findEdgeForVertex( h.v );
			}
			
			correctNEHI( hinit );
			
			if( REMOVE_INVALIDS ){
				// now do some additional removal
				for each( h in nowRemovedHEdges ){
					if( /*(h.nehi == h )&&*/h2e[h.eidx]&&(Quadric(h2e[h.eidx]).param==h.eidx) ) quadrics.remove( Quadric( h2e[ h.eidx ] ) );
				}
			}
			
			//checkDebugErrors("post");
			
			
			//check if theres sth wrong with nvhis
			/*
			if( mesh.removedVertices[ hinit.v.vi ] ) return true;
			h = hinit.v.edge;
			do{
				cur2 = h;
				do{
					if( mesh.removedHEdges[ cur2.eidx ] ){
						trace("oops0");
					}
					if( h2e[ cur2.eidx ].pos == 4294967295 ){
						trace("oops1");
					}
					cur2 = cur2.nfhi;
				}while( cur2 != h );
				
				h = mesh.hedge( h.nvhi );
			}while( h != hinit.v.edge );
			*/
			return true;
		}
		
		private function checkDebugErrors( str:String ):void{
			trace("------" + str + "------");
			for each( var q:Quadric in quadrics.heap ){
				if( mesh.removedHEdges[ q.param ]  ){
					trace("invalid param quadric not removed - " + String( q.param ) + " (" + String(q.pos) +")" );
				}
				if( h2e[ q.param ].param != q.param ){
					trace( "quadric param not equal h2e param - param:" + String( q.param ) + " v:" + String(q.v.vi) + " (" + String(q.pos) +")" );
				}
				if( mesh.removedVertices[ q.v.vi ] ){
					trace("quadric with invalid vertex:" + String( q.v.vi ) + " - " + String(q.param) + " (" + String(q.pos) + ")" );
				}
			}
		}
		
		private function deleteZeroEdges( h:HEdge , nowRemovedHEdges:Array ):void{
			var cur:HEdge = h;
			do{
				if( (cur.v.v == cur.nfhi.v.v)||(cur.v.v == cur.nfhi.nfhi.v.v)||(cur.nfhi.v.v == cur.nfhi.nfhi.v.v) ){
					if( mesh.removedFaces[ cur.face.fidx ] ) continue;
					mesh.removedHEdges[ cur.eidx ] = cur;
					mesh.removedHEdges[ cur.nfhi.eidx ] = cur.nfhi;
					mesh.removedHEdges[ cur.nfhi.nfhi.eidx ] = cur.nfhi.nfhi;
					mesh.removeFace( cur.face );
					nowRemovedHEdges.push( cur , cur.nfhi , cur.nfhi.nfhi );
				}
				cur = mesh.hedge( cur.nvhi );
			}while( cur != h );
			return;
		}
		
		/*
		Recomputed vertices adjacency
		- for every hedge in array checks whether it is deleted.
		  Then the vertices are merged together using nvhi references
		*/
		private function correctNVHI( hedges:Array ):void{
			var h:HEdge , currentHEdge:HEdge;
			var merged:Array = new Array();
			
			if( hedges.length == 0 ) return;
			for each( currentHEdge in hedges ){
				h = currentHEdge;
				if( !h ) continue;
				do{
					if( !mesh.removedHEdges[ h.eidx ] ) merged.push( h );
					h = mesh.hedge( h.nvhi );
				}while( h != currentHEdge );
			}
			
			if( merged.length == 0 ){
				if( !h ) return; // DESTROYING VERTEX
				mesh.removeVertex( h.v );
				h.v.edge = null;
			}else{
				for( var i:int = 0; i < merged.length; i++ ) HEdge( merged[ i ] ).nvhi = HEdge( merged[ (i + 1) % merged.length ] ).eidx;
				HEdge( merged[ 0 ] ).v.edge = HEdge( merged[ 0 ] );
			}
		}
		
		private function correctNEHI( hinit:HEdge ):Boolean{
			var h:HEdge = hinit.v.edge;
			var first:HEdge;
			if( !h ) return false;
			var nehis:Array = new Array();
			var cnt:int;
			if( mesh.removedVertices[ hinit.v.vi ] ) return false;
			do{
				if( !nehis[ h.nfhi.v.vi ] ) nehis[ h.nfhi.v.vi ] = new Array();
				if( !nehis[ h.nfhi.nfhi.v.vi ] ) nehis[ h.nfhi.nfhi.v.vi ] = new Array();
				nehis[ h.nfhi.v.vi ].push( h );
				nehis[ h.nfhi.nfhi.v.vi ].push( h.nfhi.nfhi );
				h = mesh.hedge( h.nvhi );
			}while( h != hinit.v.edge );
			
			for each( var a:Array in nehis ){
				first = h = a.pop();
				h2e[ first.eidx ].param = first.eidx;
				while( a.length > 0 ){
					h.nehi = a.pop();
					if( h2e[ h.nehi.eidx ] != h2e[ first.eidx ] ){
						if( REMOVE_INVALIDS ) quadrics.remove( Quadric(h2e[ h.nehi.eidx ]) );
						h2e[ h.nehi.eidx ] = h2e[ first.eidx ];
					}
					h = h.nehi;
				}
				h.nehi = first;
			}
			return true;
		}
		
		private function findNehi( h:HEdge ):int{
			var cur:HEdge;
			var cur2:HEdge;
			cur = h;
			cur2 = h.nfhi;
			do{
				if( (!mesh.removedHEdges[ cur.eidx ])&&(cur.nfhi.v.vi == cur2.v.vi) ) return cur.eidx; 
				cur = mesh.hedge( cur.nvhi );
			}while( cur != h );
			
			h = h.nfhi;
			do{
				if( (!mesh.removedHEdges[ cur2.eidx ])&&( cur2.nfhi.v.vi == cur.v.vi ) ) return cur2.eidx; 
				cur2 = mesh.hedge( cur2.nvhi );
			}while( cur2 != h );
			return -1;
		}
		
		private function findEdgeForVertex( v:Vertex ):void{
			if( v.edge == mesh.hedge( v.edge.nvhi ) ){ trace("ERROR: vertex with one edge?"); }
			else{
				var h:HEdge = v.edge;
				var newEdge:HEdge = null;
				var done:Array = new Array();
				do{
					done[ h.eidx ] = true;
					if( !mesh.removedHEdges[ h.eidx ] && mesh.hedge( h.eidx ) ){
						newEdge = h;
						break;
					} 
					h = mesh.hedge( h.nvhi );
				}while( !done[ h.eidx ] );
				if(  newEdge == null ){
					trace("couldnt find new edge for vertex");
					mesh.removeVertex( v );
					// push other deleted verts
				} 
				v.edge = newEdge;
			}
		}
		
		public function cleanupCollapse():void{
			var h:HEdge;
			var v:Vertex;
			
			// deleting deleted vertices
			
			for each( v in mesh.removedVertices ){
				vertexQuadrics[ v.vi ] = vertexQuadrics[ vertexQuadrics.length - 1 ];
				vertexQuadrics.pop();
			}
			// ** updating quadrics array **
			
			for each( h in mesh.removedHEdges ){
				h2e[ h.eidx ] = h2e[ mesh.numHEdges - 1 ];
				//h2e[ h.eidx ].param = h.eidx;
				h2e.pop();
			}
			mesh.cleanupCollapse();
		}
		
		public function cleanupCollapse2():void{
			// this may slow. and breakz edge numeration
			mesh.cleanupCollapse();
			// this... breakz down shit. so we are settin uninitialised again.
			quadrics.clear();
			h2e.splice( 0 );
			vertexQuadrics.splice( 0 );
			initialised = false;
		}
		
		/*
		###########################################################################
		#                                VALiDATi0N                               #
		###########################################################################
		
		*/
		
		private function setPenalties( val:Quadric , h:HEdge ):void{
			var excluded:Array = new Array();
			var cur:HEdge;
			var sum:Number = 0;
			
			if( VALIDITY_THRESHOLD + COMPACTNESS_THRESHOLD ){
				cur = h;
				do{
					excluded[ cur.eidx ] = true;
					cur = cur.nehi;
				}while( cur != h );
			}
			if( VALIDITY_THRESHOLD ){
				var nfail:Number = 0;
				nfail += checkValidity( h , val.v , excluded );
				nfail += checkValidity( h.nfhi , val.v , excluded );
				if( nfail != 0 ) sum += nfail*VALIDITY_RATIO;
			}
			if( COMPACTNESS_THRESHOLD ){
				var c_min:Number = 0;
				c_min = checkCompactness( h , val.v , excluded );
				c_min = Math.min( c_min , checkCompactness( h.nfhi , val.v , excluded ) );
				if( c_min < COMPACTNESS_THRESHOLD )
	    			sum += COMPACTNESS_RATIO*(1-c_min);
			}
			if( SHARP_EDGE_THRESHOLD ){
				sum += SHARP_EDGE_RATIO*checkSharpEdges( h  );
			}
			if( MAT_DISC_RATIO ){
				sum += MAT_DISC_RATIO*checkMatDiscs( h );
			}
			val.value -= sum;
		}
		/*
		h is a hedge to check
		vnew is a vertex after collapse
		excludeFaces is an array of faces adjacent to edge being collapsed
		*/
		private function checkValidity( h:HEdge , vnew:Vertex , excludeFaces:Array ):uint{
			var cur:HEdge = h;
			var f:Face;
			var dyx:Number3D, dvx:Number3D , dvn:Number3D;
			var fn:Number3D , n:Number3D;
			//var x:Number3D, y:Number3D, v:Number3D;
			var faces:Array = new Array();
			var failed:uint = 0;
			
			//v = new Number3D( h.v.x , h.v.y , h.v.z );
			do{
				f = cur.face;
				if( !faces[ cur.eidx ] && !excludeFaces[ f.fidx ] ){
					// if this face will be altered
					faces[ cur.eidx ] = true;
					dyx = new Number3D( cur.nfhi.nfhi.v.v.x - cur.nfhi.v.v.x , 
										cur.nfhi.nfhi.v.v.y - cur.nfhi.v.v.y ,
										cur.nfhi.nfhi.v.v.z - cur.nfhi.v.v.z );
					dvx = new Number3D( cur.v.v.x - cur.nfhi.v.v.x , 
										cur.v.v.y - cur.nfhi.v.v.y ,
										cur.v.v.z - cur.nfhi.v.v.z );
					dvn = new Number3D( vnew.v.x - cur.nfhi.v.v.x , 
										vnew.v.y - cur.nfhi.v.v.y ,
										vnew.v.z - cur.nfhi.v.v.z );
					fn = Number3D.cross( dyx, dvx );
					n  = Number3D.cross( fn , dyx );
					n.normalize();
					if( Number3D.dot( dvn , n ) < VALIDITY_THRESHOLD*Number3D.dot( dvx , n ) ) failed++;
				}
				cur = mesh.hedge( cur.nvhi );
			}while( cur != h );
			return failed;
		}
		
		private function checkCompactness( h:HEdge , vnew:Vertex , excludeFaces:Array ):Number{
			var cur:HEdge = h;
			var f:Face;
			var faces:Array = new Array();
			var v1:Vertex , v2:Vertex;
			var ret:Number = 1;
			var min:Number;
			var lowerpart:Number;
			var i:int;
			
			const FOUR_ROOT3:Number = 6.928203230275509;
			
			do{
				f = cur.face;
				if( !faces[ cur.eidx ] && !excludeFaces[ f.fidx ] ){
					faces[ cur.eidx ] = true;
					v1 = cur.nfhi.v;
					v2 = cur.nfhi.nfhi.v;
					
					lowerpart = ( v2.v.x   - v1.v.x )*( v2.v.y - v1.v.y     )*( v2.v.z   - v1.v.z ) +
								  ( vnew.v.x - v2.v.x )*( vnew.v.y - v2.v.y   )*( vnew.v.z - v2.v.z ) +
								  ( v1.v.x - vnew.v.x )*( v1.v.y   - vnew.v.y )*( v1.v.z - vnew.v.z );
					min = FOUR_ROOT3 * Quadric.GET_AREA_V( vnew.v , v1.v , v2.v ) / lowerpart;
					if( min > 1 ) min = 1;
					else if( min < 0 ) min = 0;
					if( min < ret) ret = min;
				}
				cur = mesh.hedge( cur.nvhi );
			}while( cur != h );
			return ret;
		}
		
		private function checkSharpEdges( h:HEdge ):Number{
			var f:Face;
			var cur:HEdge;
			var kriss:Number3D;
			var kross:Number3D;
			
			if( h.nehi == h ) return 1.0; 
			else{
				cur = h;
				do{
					kriss = cur.face.pv3dFace.faceNormal;
					kross = cur.nehi.face.pv3dFace.faceNormal;
					
					if( ( Number3D.sub( kriss , kross ).moduloSquared ) >= 2 ){
					// if angle between normals exceeds 90
						return 1;
					}
					
					if( h.nehi.nehi == h ) break;
					cur = cur.nehi;
				}while( cur != h );	
			}
			return 0;	
					
		}
		
		private function checkMatDiscs( h:HEdge ):Number{
			var diff:Dictionary = new Dictionary();
			var matNum:uint = 0;
			var cur:HEdge = h;
			
			do{
				if( cur.face.pv3dFace.material && ( !diff[ cur.face.pv3dFace.material ] ) ){
				// edge divides different materials = discontinuity
					if( ++matNum == 2 ) return 1;
					diff[ cur.face.pv3dFace.material ] = true;
				}
				cur = cur.nehi;
			}while( cur != h );
			
			return 0;
		}
		
		/* ########################################################################
		 * #                           UTiLS                                      #
		 * ########################################################################
		 */
		
		
		
		public function destroy():void{
			currentMaterial = null;
			mesh = null;
			h2e.splice(0);
			quadrics.heap.splice(0);
			states.splice(); // perhaps remove every array in st8s
		}
		
		public function get busy():Boolean{
			return _busy;
		}
		
		public function get info():String{
			return "Vert: " + String( mesh.vertices.length ) + " Faces: " + String( mesh.numFaces ) + " HEdges: " + String( mesh.numHEdges );
		}
		
	}
}