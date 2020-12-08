class Level extends dn.Process {
	public var game(get,never) : Game; inline function get_game() return Game.ME;
	public var fx(get,never) : Fx; inline function get_fx() return Game.ME.fx;

	public var cWid(get,never) : Int; inline function get_cWid() return level.l_Collisions.cWid;
	public var cHei(get,never) : Int; inline function get_cHei() return level.l_Collisions.cHei;

	public var level : World_Level;
	var tilesetSource : h2d.Tile;

	var marks : Map< LevelMark, Map<Int,Bool> > = new Map();
	var invalidated = true;

	var lightWrapper : h2d.Object;
	var front : h2d.TileGroup;
	var details : h2d.TileGroup;
	var walls : h2d.TileGroup;
	var bg : h2d.TileGroup;
	var dark : h2d.TileGroup;
	var stamps : h2d.TileGroup;
	var extraCollMap : Map<Int,Bool> = new Map();

	public var haloMask : h2d.Graphics;

	public var fakeLight(default,set) = 1.0;


	public function new(l:World_Level) {
		super(Game.ME);
		createRootInLayers(Game.ME.scroller, Const.DP_BG);
		level = l;

		tilesetSource = hxd.Res.world.tileset.toTile();

		front = new h2d.TileGroup(tilesetSource);
		game.scroller.add(front, Const.DP_FRONT);

		dark = new h2d.TileGroup(tilesetSource, root);

		lightWrapper = new h2d.Object(root);
		bg = new h2d.TileGroup(tilesetSource, lightWrapper);
		walls = new h2d.TileGroup(tilesetSource, lightWrapper);
		stamps = new h2d.TileGroup(tilesetSource, lightWrapper);
		details = new h2d.TileGroup(Assets.tiles.tile, lightWrapper);

		haloMask = new h2d.Graphics(lightWrapper);
		haloMask.beginFill(0xffffff);
		haloMask.drawCircle(0,0,Const.GRID*5);
		haloMask.visible = false;

		// Marking
		for(cy in 0...cHei)
		for(cx in 0...cWid) {
			if( !hasCollision(cx,cy) && !hasCollision(cx,cy-1) ) {
				if( hasCollision(cx+1,cy) && !hasCollision(cx+1,cy-1) )
					setMarks(cx,cy, [Grab,GrabRight]);

				if( hasCollision(cx-1,cy) && !hasCollision(cx-1,cy-1) )
					setMarks(cx,cy, [Grab,GrabLeft]);
			}

			if( !hasCollision(cx,cy) && hasCollision(cx,cy+1) ) {
				if( hasCollision(cx+1,cy) || !hasCollision(cx+1,cy+1) )
					setMarks(cx,cy, [PlatformEnd,PlatformEndRight]);
				if( hasCollision(cx-1,cy) || !hasCollision(cx-1,cy+1) )
					setMarks(cx,cy, [PlatformEnd,PlatformEndLeft]);
			}
		}
	}

	public function attachMainEntities() {
		var e = level.l_Entities.all_Hero[0];
		game.hero = new en.Hero(e);
		game.hero.yr = 0.4;
		game.hero.dx = 0.1;
		game.hero.dy = -0.1;

		if( level.l_Entities.all_Text!=null ) // BUG
		for(e in level.l_Entities.all_Text)
			new en.Text(e);

		if( level.l_Entities.all_Trigger!=null ) // BUG
		for(e in level.l_Entities.all_Trigger) 
			new en.Trigger(e);


		if( level.l_Entities.all_Door!=null ) // BUG
		for(e in level.l_Entities.all_Door)
			new en.Door(e);

	}

	public function attachLightEntities() {
		if( level.l_Entities.all_Torch!=null ) // BUG
		for( e in level.l_Entities.all_Torch )
			new en.Torch(e);

		if( level.l_Entities.all_Mob!=null ) // BUG
		for( e in level.l_Entities.all_Mob )
			new en.Mob(e);

		if( level.l_Entities.all_Item!=null ) // BUG
		for( e in level.l_Entities.all_Item )
			switch e.f_type {
				case _: new en.Item(e.cx, e.cy, e.f_type);
			}
	}

	override function onDispose() {
		super.onDispose();
		level = null;
		marks = null;
		tilesetSource.dispose();
		tilesetSource = null;
		front.remove();
	}

	/**
		Mark the level for re-render at the end of current frame (before display)
	**/
	public inline function invalidate() {
		invalidated = true;
	}

	/**
		Return TRUE if given coordinates are in level bounds
	**/
	public inline function isValid(cx,cy) return cx>=0 && cx<cWid && cy>=0 && cy<cHei;

	/**
		Transform coordinates into a coordId
	**/
	public inline function coordId(cx,cy) return cx + cy*cWid;


	/** Return TRUE if mark is present at coordinates **/
	public inline function hasMark(mark:LevelMark, cx:Int, cy:Int) {
		return !isValid(cx,cy) || !marks.exists(mark) ? false : marks.get(mark).exists( coordId(cx,cy) );
	}

	/** Enable mark at coordinates **/
	public function setMark(cx:Int, cy:Int, mark:LevelMark) {
		if( isValid(cx,cy) && !hasMark(mark,cx,cy) ) {
			if( !marks.exists(mark) )
				marks.set(mark, new Map());
			marks.get(mark).set( coordId(cx,cy), true );
		}
	}

	public inline function setMarks(cx,cy,marks:Array<LevelMark>) {
		for(m in marks)
			setMark(cx,cy,m);
	}

	/** Remove mark at coordinates **/
	public function removeMark(mark:LevelMark, cx:Int, cy:Int) {
		if( isValid(cx,cy) && hasMark(mark,cx,cy) )
			marks.get(mark).remove( coordId(cx,cy) );
	}

	/** Return TRUE if "Collisions" layer contains a collision value **/
	public inline function hasCollision(cx,cy) : Bool {
		return !isValid(cx,cy) ? true : level.l_Collisions.getInt(cx,cy)==0 || extraCollMap.exists(coordId(cx,cy));
	}

	/** Return TRUE if "Collisions" layer contains a collision value **/
	public inline function hasSky(cx,cy) : Bool {
		return !isValid(cx,cy) ? false : level.l_Collisions.getInt(cx,cy)==2;
	}

	public function setExtraCollision(cx,cy,v:Bool) {
		if( isValid(cx,cy) )
			if( v )
				extraCollMap.set( coordId(cx,cy), true );
			else
				extraCollMap.remove( coordId(cx,cy) );
	}

	/** Return TRUE if "Collisions" layer contains a collision value **/
	public inline function hasLadder(cx,cy) : Bool {
		return !isValid(cx,cy) ? true : level.l_Collisions.getInt(cx,cy)==1 || hasCollision(cx,cy) && level.l_Collisions.getInt(cx,cy+1)==1;
	}

	/** Render current level**/
	function render() {
		var atlasTile = Assets.ldtkTilesets.get( level.l_Collisions.tileset.identifier );		
		bg.clear();
		walls.clear();
		dark.clear();
		details.clear();
		front.clear();
		stamps.clear();


		// Entrance gate
		var e = level.l_Entities.all_Hero[0];
		if( !hasSky(e.cx,e.cy) && !hasSky(e.cx,e.cy-1) ) {
			var t = Assets.tiles.getTile("stair");
			t.setCenterRatio(0.5,1);
			details.add( e.pixelX, e.pixelY, t );
		}

		// Exit gate
		for(e in level.l_Entities.all_Trigger) {
			if( !hasSky(e.cx,e.cy) && !hasSky(e.cx,e.cy-1) && e.f_exitLevel ) {
				var t = Assets.tiles.getTile("stair");
				t.flipX(); // Flip stairs - opposite of entry gate
				t.setCenterRatio(0.5,1);
				details.add( e.pixelX, e.pixelY, t );
			}				
		}	

		// Stamps
		var tilesStamps = new h2d.TileGroup(atlasTile, root);
		level.l_Stamps.renderInTileGroup(tilesStamps, false);


		// Front
		for( autoTile in level.l_Front_elements.autoTiles ) {
			var tile = level.l_Front_elements.tileset.getAutoLayerHeapsTile(tilesetSource, autoTile);
			front.add(autoTile.renderX, autoTile.renderY, tile);
		}

		// Bg
		for( autoTile in level.l_Bg.autoTiles ) {
			var tile = level.l_Bg.tileset.getAutoLayerHeapsTile(tilesetSource, autoTile);
			bg.add(autoTile.renderX, autoTile.renderY, tile);
		}

		// Plants
		for( autoTile in level.l_Plants.autoTiles ) {
			var tile = level.l_Plants.tileset.getAutoLayerHeapsTile(tilesetSource, autoTile);
			tile.setCenterRatio();
			walls.addTransform(
				autoTile.renderX + Const.GRID*0.5 + rnd(0,6,true),
				autoTile.renderY + Const.GRID*0.5 + rnd(0,6,true),
				rnd(1, 1.5, true),
				rnd(1, 1.5, true),
				rnd(0,M.PI),
				tile
			);
		}

		// Walls
		for( autoTile in level.l_Collisions.autoTiles ) {
			var tile = level.l_Collisions.tileset.getAutoLayerHeapsTile(tilesetSource, autoTile);
			walls.add(autoTile.renderX, autoTile.renderY, tile);
		}

		// Dark
		for( autoTile in level.l_DarkRender.autoTiles ) {
			var tile = level.l_DarkRender.tileset.getAutoLayerHeapsTile(tilesetSource, autoTile);
			dark.add(autoTile.renderX, autoTile.renderY, tile);
		}
	}

	function set_fakeLight(v) {
		fakeLight = v;
		bg.alpha = walls.alpha = fakeLight;
		return fakeLight;
	}

	override function postUpdate() {
		super.postUpdate();

		lightWrapper.alpha += ( ( 1 ) - lightWrapper.alpha ) * 0.05;

		var tx = game.hero.centerX + game.hero.dir*5 + Math.cos(ftime*0.05)*2;
		var ty = game.hero.centerY + Math.sin(ftime*0.032)*2;
		haloMask.x += (tx-haloMask.x)*0.2;
		haloMask.y += (ty-haloMask.y)*0.2;

		haloMask.scaleX += (0.3 + Math.cos(ftime*0.03)*0.04 - haloMask.scaleX) * 0.07;
		haloMask.scaleY += (0.3 + Math.sin(ftime*0.04)*0.03 - haloMask.scaleY) * 0.07;

		if( invalidated ) {
			invalidated = false;
			render();
		}

	}
}