package qemlive.hedge{
	
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Dictionary;
	
	import org.papervision3d.Papervision3D;
	import org.papervision3d.core.data.UserData;
	import org.papervision3d.core.geom.TriangleMesh3D;
	import org.papervision3d.core.geom.renderables.Triangle3D;
	import org.papervision3d.core.geom.renderables.Vertex3D;
	import org.papervision3d.core.math.Number3D;
	import org.papervision3d.core.math.NumberUV;
	import org.papervision3d.core.ns.pv3dview;
	import org.papervision3d.core.proto.GeometryObject3D;
	import org.papervision3d.core.proto.MaterialObject3D;
	import org.papervision3d.core.render.AbstractRenderEngine;
	import org.papervision3d.materials.BitmapMaterial;
	import org.papervision3d.materials.special.CompositeMaterial;
	import org.papervision3d.materials.utils.MaterialsList;
	import org.papervision3d.objects.DisplayObject3D;
	import org.papervision3d.view.Viewport3D;
	
	import qemlive.Quadric;
	import qemlive.TeleQEM;
	import qemlive.hedge.Vertex;
	import qemlive.timers.ComputationTimer;
	import qemlive.timers.GeometryTimer;
	
	public class HEMesh extends TriangleMesh3D{	
		public static const TIMERCOUNT:uint = 1000; // how many triangles to process in one timer round
		public static const MODEL_VERTICES_DELETE_FRACT:uint = 10000; 
		public static var deleteSharedVerts:Boolean = false; // if true => not workin now
		
		public var vertices:Array;
		public var box:AABB;
		
		private var _faces:Array; 
		private var _hedges:Array;
		private var _vnum:uint = 0; // vertex no
		private var _ready:Boolean = false;
		private var qem:TeleQEM;
		private var attributes:uint;
		private var uniqueMaterials:Dictionary;
		public var uv_interp_method:uint = SIMPLE;
		public static const TRIVIAL:uint = 0;
		public static const SIMPLE:uint = 1;
		public static const ADVANCED:uint = 2;
		public static var swapUV:Boolean = false
		
		public function HEMesh( material:MaterialObject3D = null, vertices:Array = null, faces:Array = null , attributes:uint = TeleQEM.INTERPOLATE_UV_AND_NORMALS , name:String=null ){
			_faces = new Array();
			_hedges = new Array();
			this.vertices = new Array();
			this.attributes = attributes;
			this.uv_interp_method = ADVANCED;
			uniqueMaterials = new Dictionary();
			box = new AABB(); 
			if( material && vertices && faces ){
			}else{
				material = new MaterialObject3D();
				vertices = new Array();
				faces = new Array();
				name  = "";
			}
			super( material , vertices , faces , name );
		}
		
		public function addHEdge( h:HEdge ):HEdge{
			 h.eidx = _hedges.length;
			 _hedges.push( h ) ; 
			 return h;
		}
		
		// face is configured after addin
		public function addFace( h:HEdge ):Face{
			_faces.push( new Face( h , _faces.length ) );
			return _faces[ _faces.length - 1 ];
		}
		
		public function hedge( i:uint ):HEdge{
			return _hedges[ i ];
		}
		
		public function hedgeIdx( h:HEdge ):int{
			return h.eidx;
		}
		
		public function face( i:uint ):Face{
			return _faces[ i ];
		}
		
		public function faceIdx( f:Face ):int{
			return f.fidx;
		}
		
		public function get hedges():Array{
			return _hedges;
		}
		
		public function get numHEdges():uint{
			return _hedges.length;
		}
		
		public function get numFaces():uint{
			return _faces.length;
		}
		
		public function get numVertices():uint{
			return _vnum;
		}
		
		private var vnum:uint = 0;
		private var queued:int = 0;
		public function init( curr:DisplayObject3D = null ):void{
			if( !curr ) curr = this;
			for each( var child:DisplayObject3D in curr.children )
				init( child );
			queued++;
			var timer:GeometryTimer = new GeometryTimer( 10 , curr.geometry );
			timer.addEventListener( TimerEvent.TIMER , fromGeometryObject3D );
			timer.start();
			return;
		}
		
		private function fromGeometryObject3D( evt:TimerEvent ):void{
			var time:GeometryTimer = ((GeometryTimer)(evt.target));
			var go3d:GeometryObject3D = time.go3d;
			
			if( go3d && go3d.faces && go3d.faces.length ){
				var dict:Dictionary = time.dict;
				var v0:Vertex, v1:Vertex , v2:Vertex;
				//var s0:String , s1:String , s2:String;
				var s0:Vertex3D , s1:Vertex3D , s2:Vertex3D;
				var face:Triangle3D;
				
				if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Creating geometry: " + String( go3d.faces.length - time.currentCount );
				for( var i:uint = time.currentCount*TIMERCOUNT; 
					 ( i < (time.currentCount + 1)*TIMERCOUNT ) && ( i < go3d.faces.length ); 
					 i++ )
				{
					face=Triangle3D(go3d.faces[i]);
					if( (!face.faceNormal)||(isNaN(face.faceNormal.modulo)) ) face.createNormal();
					if( !face.faceNormal.modulo ){
						continue;
					}
					
					// resetting changes vertices, though it must be done before checkin in dictionary
					if( swapUV )
						face.reset( this , face.vertices , face.material , [ new NumberUV( 1.0-face.uv0.u , face.uv0.v ) , new NumberUV( 1.0-face.uv1.u , face.uv1.v ) , new NumberUV( 1.0-face.uv2.u , face.uv2.v ) ] );
					else face.reset( this , face.vertices , face.material , face.uv );
					
					uniqueMaterials[ face.material ] = face.material;
					v0 = dict[ s0 = face.v0 ];
					v1 = dict[ s1 = face.v1 ];
					v2 = dict[ s2 = face.v2 ];
					//v0 = dict[ s0 = itoa(face.v0.toNumber3D()) ];
					//v1 = dict[ s1 = itoa(face.v1.toNumber3D()) ];
					//v2 = dict[ s2 = itoa(face.v2.toNumber3D()) ];
					
					if( ( ( v0 && v1 ) && ( v0 == v1 ) ) 
					||  ( ( v1 && v2 ) && ( v1 == v2 ) ) 
					||  ( ( v0 && v2 ) && ( v0 == v2 ) )  ) continue;
					
					if( !v0 ){ 
						v0 = new Vertex( face.v0 , vnum++ , geometry.vertices.length ); 
						box.expand( face.v0 );
						
						dict[ s0 ] = v0; 
						vertices.push( v0 );
						this.geometry.vertices.push( v0.v );
					}
					if( !v1 ){ 
						v1 = new Vertex( face.v1 , vnum++ , geometry.vertices.length ); 
						box.expand( face.v1 );
						
						dict[ s1 ] = v1; 
						vertices.push( v1 );
						this.geometry.vertices.push( v1.v );
					}
					if( !v2 ){ 
						v2 = new Vertex( face.v2 , vnum++ , geometry.vertices.length ); 
						box.expand( v2.v );
						
						dict[ s2 ] = v2; 
						vertices.push( v2 );
						this.geometry.vertices.push( v2.v );
					}
					
					var h0:HEdge = addHEdge( new HEdge( v0 ) );
					var h1:HEdge = addHEdge( new HEdge( v1 ) );
					var h2:HEdge = addHEdge( new HEdge( v2 ) );
					
					var f:Face = addFace( h0 );
					
					f.pv3dFace = face;
					face.userData = new UserData( f );
					f.finitNum = geometry.faces.length;
					this.geometry.faces.push( face );
					
					if( !face.uv0 ){
						face.uv0 = new NumberUV();
					}
					if( !face.uv1 ){
						face.uv1 = new NumberUV();
					}
					if( !face.uv2 ){
						face.uv2 = new NumberUV();
					}
					
					h0.face = f;
					h0.nfhi = h1;
					h0.nehi = h0;
					h0.setNextEdgeHEdgeOpposite( false );
					
					h1.face = f;
					h1.nfhi = h2;
					h1.nehi = h1;
					h1.setNextEdgeHEdgeOpposite( false );
					
					h2.face = f;
					h2.nfhi = h0;
					h2.nehi = h2;
					h2.setNextEdgeHEdgeOpposite( false );
				}
				if( i == go3d.faces.length ){
					time.stop();
					this.geometry.ready = true;
					if( --queued==0 ){
						setVCount();
						computeAdjacency();
					}
				}
			} else{
				time.stop();
				this.geometry.ready = true;
				if( --queued==0 ){
					setVCount();
					computeAdjacency();
				}
			} 
		}
		
		private var precision:Number = 100000;
		private function itoa( n:Number3D ):String{
			//return 'x:' + n.x.toFixed(0) + ' y:' + n.y.toFixed(0) + ' z:' + n.z.toFixed(0);
			return 'x:' + n.x + ' y:' + n.y + ' z:' + n.z;
		}
		
		private function isEqualV3D( v0:Vertex3D , v1:Vertex3D ):Boolean{ 
			if( ( v0.x == v1.x ) && ( v0.y == v1.y ) && ( v0.z == v1.z ) ) return true;
			else return false;
		}
		
		public function setVCount():void{
			var mat:MaterialObject3D;
			var matcnt:int = 0;
			for each( mat in uniqueMaterials )	matcnt++;
			if( matcnt <= 1 ){
				this.material = mat;
			}else{
				this.materials = new MaterialsList();
				for each( mat in uniqueMaterials ){
					materials.addMaterial( mat );
				}
			}
			uniqueMaterials = new Dictionary();
			_vnum = this.vertices.length;
		}
/*
		###################################################################################################
		#																								  #
		#										Compute Adjacency										  #
		#																								  #
		###################################################################################################
		
		connects HEdges and faces to make valid Half-edge mesh
		
		computeAdjaency calls:
		if deleteSharedVerts: deleteSharedVertsPart0 -> deleteSharedVertsPart1 -> deleteSharedVertsPart2 -> until ok
		a) findHEdgesPerVertexPart0 -> findHEdgesPerVertexPart1 -> findHEdgesPerVertexPart2 ->
		b) computeAdjacencyPart0 -> computeAdjacencyPart1
		
	*/	
	
		private function findHEdgesPerVertexPart0( evt:TimerEvent ):void{ 
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			var h:HEdge;
			var hi:int;
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Finding hedges vertices: " + String( _hedges.length - TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount );
			for ( hi = TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount; 
				  (hi < _hedges.length)&&( hi < TeleQEM.TIMERCOUNT_LIGHT*(ctime.currentCount+1) ); 
				  hi++ )
			{
				h = hedge( hi );
				if( h.v.edge != null ){
					var fvhi:HEdge = h.v.edge;
					h.nvhi = fvhi.nvhi?fvhi.nvhi:-1;
					fvhi.nvhi = hi;
				}else{
					h.v.edge = h;
				}
			}
			
			if( hi == _hedges.length ){
				ctime.reset();
				ctime.removeEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart0 );
				ctime.addEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart1 );
				ctime.start();
			} 
		}
		
		private function findHEdgesPerVertexPart1( evt:TimerEvent ):void{
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			var last:HEdge , hi:int , i:int;
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Linking loose ends: " + String( vertices.length - TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount );
			// link loose ends to create cycles
			for ( i = TeleQEM.TIMERCOUNT_HARD*ctime.currentCount; 
			      ( i < vertices.length )&&( i < TeleQEM.TIMERCOUNT_LIGHT*(ctime.currentCount+1) ); i++ )
			{
				if( Vertex(vertices[ i ] ).edge == null ){
					trace("Number holes?");
					continue; // shouldn't occur	
				} 
				last = Vertex( vertices[ i ] ).edge;
				hi = last.eidx;
				
				var donator:Array = new Array();
				//var shitCatcher:int = 0;
				while( last.nvhi != -1 ){
					if( donator[ last.eidx ] ){
						donator = null;
						break;
					}else donator[ last.eidx ] = true;
					last = hedge( last.nvhi ); 
				}
				if( donator != null ) last.nvhi = hi;
			}
			
			if( i == vertices.length ){
				ctime.reset();
				ctime.removeEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart1 );
				ctime.addEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart2 );
				ctime.start();
			} 
		}
		
		private function findHEdgesPerVertexPart2( evt:TimerEvent ):void{
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			var last:int , hi:int , i:int;
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Creating cycles: " + String( _hedges.length - TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount );
			// create self-referencing cycles for the rest
			for ( i = TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount; 
			      ( i < _hedges.length )&&( i < TeleQEM.TIMERCOUNT_LIGHT*(ctime.currentCount+1) ); i++ )
			{
				if( -1 == hedge( i ).nvhi ) {
					hedge( i ).nvhi = i;
				}
			}
			
			if( i == _hedges.length ){
				// nvhi is circular now :O
				ctime.reset();
				ctime.removeEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart2 );
				//findHEdgesSharingVertices( );
				ctime.addEventListener( TimerEvent.TIMER , computeAdjacencyPart0 );
				ctime.start();
			} 
		}
/*
		THIS IS TURNED OFF 'CAUSE IN 'LIVE' MODE WE DONT CARE ABOUT DUPLICATES
		
		private function deleteSharedVerticesPart0( evt:TimerEvent ):void{
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			var vi:int;
			
			if( !ctime.vhash ) ctime.vhash = new OCTree( box );
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Building OCTree: " + String( vertices.length - TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount );
			for ( vi = TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount; 
				  (vi < vertices.length)&&( vi < TeleQEM.TIMERCOUNT_LIGHT*(ctime.currentCount+1) ); 
				  vi++ )
			{
				ctime.vhash.addVertex( Vertex(vertices[ vi ]) );
			}
			
			if( vi == vertices.length ){
				removedVertices = new Array();
				removedFaces = new Array();
				removedHEdges = new Array();
				ctime.reset();
				ctime.removeEventListener( TimerEvent.TIMER , deleteSharedVerticesPart0 );
				ctime.addEventListener( TimerEvent.TIMER , deleteSharedVerticesPart1 );
				ctime.start();
			} 
		}
		
		private function deleteSharedVerticesPart1( evt:TimerEvent ):void{
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			var vi:int; var v:Vertex;
			var done:Array = ctime.done;
			var vhash:OCTree = ctime.vhash;
			var maxDist:Number = ctime.maxdist;
			var pmd2:Number = ctime.maxdist*ctime.maxdist;
			var found:Array;
			var computeCycle:int = Math.max( 1 , 1000000/vertices.length );
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Searching duplicated vertices: " + String( vertices.length - computeCycle*ctime.currentCount );
			for ( vi = computeCycle*ctime.currentCount; 
				  (vi < vertices.length)&&( vi < computeCycle*(ctime.currentCount+1) ); 
				  vi++ )
			{
				v = vertices[ vi ];
				if( done[ v.vi ] ) continue;
				found = vhash.findData( vertices[ v.vi ] , maxDist );
				
				for each( var data:Vertex in found ){
		// ### cant merge one vertex with more than one other - thats one con of this method ###
					if( done[ data.vi ] ) continue;
					if( (Number3D.sub( data.v.toNumber3D() , v.v.toNumber3D() ).moduloSquared <= pmd2 ) 
						&& ( data.v.normal.x*v.v.normal.x + data.v.normal.y*v.v.normal.y + data.v.normal.z*v.v.normal.z >= .95 )
					 ){ 
						if( data.vi != v.vi ){
							// done[ data.vi ] = true; 
							removedVertices.push({ num:data.vi , vertex:data } );
							// this isnt necess
							// Vertex.COPY( data , v );
							data.vi = v.vi; 
						}
					}

				}
				// all deleted are DONE
				done[ v.vi ] = true;
			}
			
			if( vi == vertices.length ){
				ctime.reset();
				ctime.removeEventListener( TimerEvent.TIMER , deleteSharedVerticesPart1 );
				ctime.addEventListener( TimerEvent.TIMER , deleteSharedVerticesPart2 );
				ctime.start();
			} 
		}
		
		private function deleteSharedVerticesPart2( evt:TimerEvent ):void{
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			var fi:int;
			var h:HEdge; var f:Face;
			
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Correcting hedge nums: " + String( _faces.length - TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount );
			for ( fi = TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount; 
				  (fi < _faces.length)&&( fi < TeleQEM.TIMERCOUNT_LIGHT*(ctime.currentCount+1) ); 
				  fi++ )
			{
				f = _faces[ fi ];
				h = f.fh;
				
				if( ( h.v.vi == h.nfhi.v.vi ) || (h.v.vi == h.nfhi.nfhi.v.vi) || (h.nfhi.v.vi == h.nfhi.nfhi.v.vi) || (f.pv3dFace.faceNormal.moduloSquared==0) ){
					removedFaces[ fi ] = f;
					removedHEdges[ h.eidx ] = h;
					removedHEdges[ h.nfhi.eidx ] = h.nfhi;
					removedHEdges[ h.nfhi.nfhi.eidx ] = h.nfhi.nfhi;
				}else{ // CORRECTING REMOVED
					h.v = vertices[ h.v.vi ];
					h.nfhi.v = vertices[ h.nfhi.v.vi ];
					h.nfhi.nfhi.v = vertices[ h.nfhi.nfhi.v.vi ];
				}
			}
			
			if( fi == _faces.length ){
				var obj:Object;
				for each( obj in removedVertices ){
					obj.vertex.vi = obj.num;
				}
				
				for each( obj in removedVertices ){
					vertices[ obj.vertex.vi ] = vertices[ vertices.length - 1 ];
					vertices[ obj.vertex.vi ].vi = obj.vertex.vi;
					vertices.pop();
				}
				
				ctime.reset();
				ctime.removeEventListener( TimerEvent.TIMER , deleteSharedVerticesPart2 );
				
				
				if( !ctime.merged && removedVertices.length ){
					ctime.vhash = null;
					ctime.merged = true;
					ctime.done.splice( 0 );
					ctime.done = new Array( vertices.length );
					ctime.addEventListener( TimerEvent.TIMER , deleteSharedVerticesPart0 );
				}else ctime.addEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart0 );
				
								
				removedVertices.splice( 0 );
				cleanupCollapse();
				
				var done:Array = new Array();
				for( var i:int = 0; i < _hedges.length; i++ ){
					done[ HEdge( _hedges[ i ] ).v.vi ] = 1;
				}
				for( i = 0; i < vertices.length; i++ ){
					if( !done[ i ] ){
						removedVertices.push( vertices[ i ] );//trace("ERROR");
					}
				}
				cleanupCollapse();
				
				ctime.start();
			} 
		}*/
		
		public function computeAdjacency(  ):void{
			//done[] = false/null
			var done:Array = new Array( vertices.length );
			var ctime:ComputationTimer = new ComputationTimer( 1 , done );
			
			//if( deleteSharedVerts ){
			//	ctime.maxdist = box.stddev.modulo/MODEL_VERTICES_DELETE_FRACT;;
			//	ctime.addEventListener( TimerEvent.TIMER , deleteSharedVerticesPart0 );
			//}else{	
				ctime.addEventListener( TimerEvent.TIMER , findHEdgesPerVertexPart0 );
				ctime.start();
			//}
		}
		
		private function computeAdjacencyPart0( evt:TimerEvent):void{
			//findHEdgesSharingVertices( v2hi , nvhi );
			var ctime:ComputationTimer = (ComputationTimer)(evt.target);
			
			var hi1:int = -1;
			var h1:HEdge , hi1_:int , h2:HEdge , hi2:int , hi2_:int , h3:int , h3_:HEdge , hi3_:int;
			
			// merge circular
			var end:int;
			var next:int;
			var ae:int , be:int;
			var proceed:Boolean;
			
			if( TeleQEM.progressInfo ) TeleQEM.progressInfo.text = "Computing adjacency: " + String( vertices.length - TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount );
			for ( var i:int = TeleQEM.TIMERCOUNT_LIGHT*ctime.currentCount; 
			      ( i < vertices.length )&&( i < TeleQEM.TIMERCOUNT_LIGHT*(ctime.currentCount+1) ); i++ )
			{
				if( vertices[ i ].edge == null ){
					trace("Number holes?");
					continue; // shouldn't occur	
				} 
				
				hi1 = hi1_ = Vertex( vertices[ i ] ).edge.eidx;
				// find all hedges from v2hi[ i ]
				do{
					//done[ hi1 ] = true;
					
					h1 = _hedges[ hi1 ];
					hi2_ = h1.nfhi.eidx;
					// all hedges from h1 target
					hi2 = hi2_;
					do{
						h2 = _hedges[ hi2 ];
						
						// if hedge returns to vi1, adjacency
						hi3_ = h2.nfhi.eidx;
						h3_ = hedge( hi3_ );
						h3 = Vertex( vertices[ h3_.v.vi ] ).edge.eidx;
						
						if( ( h3 == hi1_ )&&( hi1 != hi2 ) ){
							proceed = true;
							end = hi1;
							while( ( next = HEdge(_hedges[ end ] ).nehi.eidx ) != hi1 ){
								end = next;
								if( hi2 == next ){
									proceed = false;
									break;
								}
							}
							ae = end;
							
							if( proceed ){
								end = hi2;
								while( ( next = HEdge(_hedges[ end ]).nehi.eidx ) != hi2 ){
									end = next;
									if( hi1 == next ){
										proceed = false;
										break;
									}
								}
								be = end;
								if( proceed ){
									if( ae == hi2 ){ trace( "ERROR. ae shouldn't be hi2" ); break;}
									if( be == hi1 ){ trace( "ERROR. be shouldn't be hi1" ); break; }
									
									HEdge(_hedges[ ae ]).nehi = HEdge(_hedges[ hi2 ]);
									HEdge(_hedges[ ae ]).setNextEdgeHEdgeOpposite( true );
									
									HEdge(_hedges[ be ]).nehi = HEdge(_hedges[ hi1 ])
									HEdge(_hedges[ be ]).setNextEdgeHEdgeOpposite( true );
								}
							}
						}
						hi2 = HEdge(_hedges[ hi2 ]).nvhi;
					}while( hi2 != hi2_ );
					hi1 = HEdge(_hedges[ hi1 ]).nvhi;
				}while( hi1 != hi1_ );
			}
			
			if( i == vertices.length ){
				ctime.stop();
				_ready = true;
				qem = new TeleQEM( this );
				qem.init( completeEvent , attributes );
			}
		}
		
		private function completeEvent():void{
			dispatchEvent( new Event( Event.COMPLETE ) );
		}
		
		
/*
		###################################################################################################
		#																								  #
		#											KOLLAPZ												  #
		#																								  #
		###################################################################################################
		*/
		public var removedHEdges:Array;
		public var removedFaces:Array;
		public var removedVertices:Array;
		
		public function collapse( vert:Vertex3D ):Boolean{
			var h:uint;
			var v:Vertex2;
			var vi:int = -1;
			if( _ready ){
				while( vert != Vertex(vertices[ ++vi ]).v );
				v = Vertex2.fromVertex( Vertex(vertices[vi]) , this );
				return qem.collapse( v.edge.eidx , v );
			} 
			else return false;
		}
		
		public function uncollapse():void{
			if( _ready ){
				qem.uncollapse();
			}
		}
		public function decimate():void{
			if( _ready ) qem.decimate( true );
		}
		public function newqem( f:uint , a:Boolean = false ):void{
			if( _ready ) qem.newqem( f , onf , a );
		}
		private function onf():void{
			dispatchEvent( new Event( TeleQEM.COMPLETE_DECIMATION ) );
		}
		
		public function cleanupCollapse( ):void{
			for each( var f:Face in removedFaces ){
				_faces[ f.fidx ] = _faces[ numFaces - 1 ];
				_faces[ f.fidx ].fidx = f.fidx;
				_faces.pop();
			}
			
			for each( var h:HEdge in removedHEdges ){
				_hedges[ h.eidx ] = _hedges[ numHEdges - 1 ];
				_hedges[ h.eidx ].eidx = h.eidx;
				_hedges.pop();
			}
			
			for each( var v:Vertex in removedVertices ){
				vertices[ v.vi ]    = vertices[ vertices.length - 1 ];
				vertices[ v.vi ].vi = v.vi;
				vertices.pop();
			}
			
			if( removedHEdges ) removedHEdges.splice( 0 );
			if( removedVertices ) removedVertices.splice( 0 );
			if( removedFaces ) removedFaces.splice( 0 );
		}
		
		private function mergeVertices2QEM( v0:Vertex , v1:Vertex ):void{
			var h:HEdge;
			h = v1.edge;
			do{
				// if( ( h.nfhi.v == v0 ) || ( h.nfhi.nfhi.v == v0 ) ){	
				// }else 
				h.v = v0;
				h = hedge( h.nvhi );
			}while( h != v1.edge );
			
			vertices[ v1.vi ] = vertices[ vertices.length - 1 ];
			vertices[ v1.vi ].vi = v1.vi;
			vertices.pop();
		}
		
		public function mergeVerticesQEM( hinit:HEdge , newv:Vertex2 ):void{
			// ##### change vertices
			// we change this Vertex
			var v0:Vertex = hinit.v;
			// and this is changed to v0
			var v1:Vertex = hinit.nfhi.v;
			
			var h:HEdge;
			var q:Quadric;
			var switched:Boolean = false;
			
			// sanity chex
			if( !removedVertices) removedVertices = new Array();
			if( removedVertices[ v0.vi ] ){
				trace( "merging removed" );
				removedVertices[ v0.vi ] = null;
			}
			if( removedVertices[ v1.vi ] ){
				trace( "merging removed" );
				removedVertices[ v0.vi ] = null;
			}
			if( v0.v == v1.v ){
				trace("two verts eq");
			}
			
			
			v0.edge = hinit;
			
			// switch vertices if the changed one is second
			if( newv.vi != v0.vi ){
				if( newv.vi != v1.vi ){ trace("hey, sumtin wrong");}
				var tmp:Vertex3D = v0.v;
				v0.v = v1.v;
				v1.v = tmp;
				
				var tmp2:int = v0.vinitNum;
				v0.vinitNum = v1.vinitNum;
				v1.vinitNum = tmp2;
				
				v0.v.extra = v0;
				v1.v.extra = v1;
				
				switched = true;
			}
			//remove v1
			removeVertex( v1 );
			
			
			// gather uv's
			// from destroyed unmoved vertex
			var uvs:Array = new Array();
			var neutral:Vertex;
			
			h = hinit;
			do{
				if( (h.nfhi.nfhi.v != v0)&&(h.nfhi.nfhi.v != v1 ) ) neutral = h.nfhi.nfhi.v;
				else if( (h.nfhi.v != v0)&&(h.nfhi.v != v1 ) ) neutral = h.nfhi.v;
				else if( (h.v != v0)&&(h.v != v1 ) ) neutral = h.v;
				else{ trace("no neutral found?" ); }
				if( h.face.pv3dFace.v0 == v0.v ) uvs[ neutral.vi ] = new UVInterp( h.face.pv3dFace.faceNormal , h.face.pv3dFace.uv0.clone() );
				else if( h.face.pv3dFace.v1 == v0.v ) uvs[ neutral.vi ] = new UVInterp( h.face.pv3dFace.faceNormal , h.face.pv3dFace.uv1.clone() );
				else if( h.face.pv3dFace.v2 == v0.v ) uvs[ neutral.vi ] = new UVInterp( h.face.pv3dFace.faceNormal , h.face.pv3dFace.uv2.clone() );
				else{ trace("hey, no uv found");}
				
				h = h.nehi;
			}while( h != hinit );
			
			// get average UV for averaged measure
			var avg:NumberUV = new NumberUV();
			var i:int = 0;
			for each( var uv:UVInterp in uvs ){
				avg.u += uv.uv.u;
				avg.v += uv.uv.v; i++;
			}
			avg.u /= i; avg.v /= i;
			
			do{
				if( switched ){
					if( h.face.pv3dFace.v0 == v1.v ){
						h.face.pv3dFace._uvArray[0] = h.face.pv3dFace.uv0 = getUV( uvs , h , avg );
						h.face.pv3dFace.vertices[ 0 ] = h.face.pv3dFace.v0 = v0.v;
					}else if( h.face.pv3dFace.v1 == v1.v ){
						h.face.pv3dFace._uvArray[1] = h.face.pv3dFace.uv1 = getUV( uvs , h , avg );
						h.face.pv3dFace.vertices[ 1 ] = h.face.pv3dFace.v1 = v0.v;
					}else if( h.face.pv3dFace.v2 == v1.v ){
						h.face.pv3dFace._uvArray[2] = h.face.pv3dFace.uv2 = getUV( uvs , h , avg );
						h.face.pv3dFace.vertices[ 2 ] = h.face.pv3dFace.v2 = v0.v;
					}
					h.face.updateMatrices();
				}
				
				if( h.v != v0 ){
					trace("???");
				}
				q = Quadric( qem.h2e[ h.eidx ] );
				if( q.v.vi == v1.vi ) q.v.vi = v0.vi;
				q = Quadric( qem.h2e[ h.nfhi.nfhi.eidx ] );
				if( q.v.vi == v1.vi ) q.v.vi = v0.vi;
				
				h = hedge( h.nvhi );
			}while( h != hinit );
			
			h = hinit.nfhi;
			do{
				if( !switched ){
					if( h.face.pv3dFace.v0 == v1.v ){
						h.face.pv3dFace._uvArray[ 0 ] = h.face.pv3dFace.uv0 = getUV( uvs , h , avg );
						h.face.pv3dFace.vertices[ 0 ] = h.face.pv3dFace.v0 = v0.v;
					}else if( h.face.pv3dFace.v1 == v1.v ){
						h.face.pv3dFace._uvArray[ 1 ] = h.face.pv3dFace.uv1 = getUV( uvs , h , avg );
						h.face.pv3dFace.vertices[ 1 ] = h.face.pv3dFace.v1 = v0.v;
					}else if( h.face.pv3dFace.v2 == v1.v ){
						h.face.pv3dFace._uvArray[ 2 ] = h.face.pv3dFace.uv2 = getUV( uvs , h , avg );
						h.face.pv3dFace.vertices[ 2 ] = h.face.pv3dFace.v2 = v0.v;
					}
					h.face.updateMatrices();
				}
				h.v = v0;
				
				q = Quadric( qem.h2e[ h.eidx ] );
				if( q.v.vi == v1.vi ) q.v.vi = v0.vi;
				q = Quadric( qem.h2e[ h.nfhi.nfhi.eidx ] );
				if( q.v.vi == v1.vi ) q.v.vi = v0.vi;
				h = hedge( h.nvhi );
			}while( h != hinit.nfhi );
			
			
			return;
		}
		
		/*
		- TRIVIAL MODE TAKES FIRST UV WHICH IS CORRECT, 
		- SIMPLE MODE TAKES ALL UV'S AND IF THERE IS SOME AMBIGUITY, IT INTERPOLATES BETWEEN UV'S
		- ADVANCED MODE TAKES INTO ACCOUNT FACE NORMALS TO RESOLVE AMBIGUITY PROBLEMS
		*/
		public function getUV( uvs:Array , h:HEdge , avg:NumberUV = null ):NumberUV{
			var v0:NumberUV;
			var v1:NumberUV;
			
			if( uv_interp_method == TRIVIAL ){
				var uvint:UVInterp = null;
				uvint = uvs[ h.v.vi ] || uvs[ h.nfhi.v.vi ] || uvs[ h.nfhi.nfhi.v.vi ];
				if( uvint ) return uvint.uv;
				else return avg;
			} 
			else if( uv_interp_method == SIMPLE ){
				if( uvs[ h.v.vi ] ){
					v0 = UVInterp(uvs[ h.v.vi ]).uv;
					if( uvs[ h.nfhi.v.vi ] ) return new NumberUV( .5*(v0.u + UVInterp(uvs[ h.nfhi.v.vi ]).uv.u ), .5*(UVInterp(uvs[ h.nfhi.v.vi ]).uv.v + v0.v) );
					else if( uvs[ h.nfhi.nfhi.v.vi ] ) return new NumberUV( .5*(v0.u + UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).uv.u ), .5*(UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).uv.v + v0.v) );
					else return v0;
				}else
				if( (uvs[ h.nfhi.v.vi ]) ){
					v0 = UVInterp(uvs[ h.nfhi.v.vi ]).uv
					if( uvs[ h.nfhi.nfhi.v.vi ]) return new NumberUV( .5*(v0.u + UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).uv.u ), .5*(UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).uv.v + v0.v) );
					else return v0;
				}else if( uvs[ h.nfhi.nfhi.v.vi ] ) return UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).uv;
				else return avg;
			}
			
			var d0:Number , d1:Number;
			if( uvs[ h.v.vi ] ){
				v0 = UVInterp(uvs[ h.v.vi ]).uv;
				if( uvs[ h.nfhi.v.vi ] ){
					v1 = UVInterp(uvs[ h.nfhi.v.vi ]).uv;
					d0 = Number3D.dot( h.face.pv3dFace.faceNormal , UVInterp(uvs[ h.nfhi.v.vi ]).normal );
					d1 = Number3D.dot( h.face.pv3dFace.faceNormal , UVInterp(uvs[ h.v.vi ]).normal );
					if( d1 > d0 ) return v0;
					else return v1;
				}else  if( uvs[ h.nfhi.nfhi.v.vi ] ){
					v1 = uvs[ h.nfhi.nfhi.v.vi ].uv;
					d0 = Number3D.dot( h.face.pv3dFace.faceNormal , UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).normal );
					d1 = Number3D.dot( h.face.pv3dFace.faceNormal , UVInterp(uvs[ h.v.vi ]).normal );
					if( d1 > d0 ) return v0;
					else return v1;
				}else return v0;
			}
			else if( uvs[ h.nfhi.v.vi ] ){
				v0 = uvs[ h.nfhi.v.vi ].uv;
				if( uvs[ h.nfhi.nfhi.v.vi ] ){
					v1 = uvs[ h.nfhi.nfhi.v.vi ].uv;
					d0 = Number3D.dot( h.face.pv3dFace.faceNormal , UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).normal );
					d1 = Number3D.dot( h.face.pv3dFace.faceNormal , UVInterp(uvs[ h.nfhi.v.vi ]).normal );
					if( d1 > d0 ) return v0;
					else return v1;
				}else return v0;
			}else if( uvs[ h.nfhi.nfhi.v.vi ] ) return UVInterp(uvs[ h.nfhi.nfhi.v.vi ]).uv;
			else{
				d1 = -2;
				for each( var obj:UVInterp in uvs ){
					d0 = Number3D.dot( h.face.pv3dFace.faceNormal , obj.normal );
					if( d0 > d1 ){
						v0 = obj.uv;
						d1 = d0;
					}
				}
				return v0?v0:avg;
			}
		}
		
		
		public function removeVertex( v:Vertex ):void{
			if( removedVertices[ v.vi ] ){ trace( "vertex already removed" ); }
			else{
				var vv:Vertex;
				var i:int;
				removedVertices[ v.vi ] = v;
				/*
				DONT REMOVE VERTICES, REMOVIN CAUSES STRANGE ERRORS.
				geometry.vertices.splice( v.vinitNum , 1 )[0];
				for( i = v.vinitNum; i < geometry.vertices.length; i++ ){
					Vertex( Vertex3D( geometry.vertices[ i ] ).extra ).vinitNum--;
				}*/
			} 
		}
		public var removedFacesNum:int = 0;
		public function removeFace( f:Face ):void{
			var i:int;
			var ff:Face;
			removedFaces[ f.fidx ] = f;
			removedFacesNum++;
			geometry.faces.splice( f.finitNum , 1 );
			//renderer.removeFromRenderList( f.pv3dFace.renderCommand );
			for( i = f.finitNum; i < geometry.faces.length; i++ ){
				Face(Triangle3D( geometry.faces[ i ] ).userData.data ).finitNum--;
			}
			/*
			for( i = f.fidx+1; i < _faces.length; i++ ){
				ff = Face( _faces[ i ] );
				if( !removedFaces[ ff.fidx ] ) ff.finitNum--;
			}*/
		}
		
		public function isReady():Boolean{
			return _ready;
		}
		
		public function destroy():void{
			qem.destroy();
			if( removedFaces ) removedFaces.splice(0);
			if( removedHEdges ) removedHEdges.splice(0);
			if( removedVertices ) removedVertices.splice(0);
			_hedges.splice(0);
			vertices.splice(0);
			_faces.splice(0);
			_ready = false;
		}
		
		
	}
}