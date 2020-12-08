import dn.Process;
import hxd.Key;

class Game extends Process {
	public static var ME : Game;
	public static var HEROLIFE : Int;

	// Hit points
	public var herolife(default,null) : Int;
	public var maxherolife(default,null) : Int;


	/** Game controller (pad or keyboard) **/
	public var ca : dn.heaps.Controller.ControllerAccess;

	/** Particles **/
	public var fx : Fx;

	/** Basic viewport control **/
	public var camera : Camera;

	/** Container of all visual game objects. Ths wrapper is moved around by Camera. **/
	public var scroller : h2d.Layers;

	/** Level data **/
	public var level : Level;

	/** UI **/
	public var hud : ui.Hud;
	

	/** Slow mo internal values**/
	var curGameSpeed = 1.0;
	var slowMos : Map<String, { id:String, t:Float, f:Float }> = new Map();

	/** LDtk world data **/
	public var world : World;

	public var hero: en.Hero;

	var fadeMask : h2d.Bitmap;

	public var curLevelIdx = 0;

	public function new() {
		super(Main.ME);
		ME = this;
		ca = Main.ME.controller.createAccess("game");
		ca.setLeftDeadZone(0.2);
		ca.setRightDeadZone(0.2);
		createRootInLayers(Main.ME.root, Const.DP_BG);

		scroller = new h2d.Layers();
		root.add(scroller, Const.DP_BG);
		scroller.filter = new h2d.filter.ColorMatrix(); // force rendering for pixel perfect

		world = new World( hxd.Res.world.world.entry.getText() );
		camera = new Camera();
		fx = new Fx();
		hud = new ui.Hud();

		fadeMask = new h2d.Bitmap( h2d.Tile.fromColor(Const.DARK_COLOR) );
		root.add(fadeMask, Const.DP_TOP);

		initHeroLife(5);
		HEROLIFE = herolife;
		maxherolife = herolife;
		startLevel(0);
	}


	function fadeIn() {
		tw.terminateWithoutCallbacks(fadeMask.alpha);
		fadeMask.visible = true;
		tw.createMs( fadeMask.alpha, 1>0, 1200, TEaseIn ).end( ()->fadeMask.visible = false );
	}

	function fadeOut() {
		tw.terminateWithoutCallbacks(fadeMask.alpha);
		fadeMask.visible = true;
		tw.createMs( fadeMask.alpha, 0>1, 2000, TEaseIn );
	}


	public function nextLevel() {
		startLevel(curLevelIdx+1);
	}	

	public function jumpToLevel(v) {
		var targetLevel = v;
		var nextLevelIdx = levelIdxFromName(targetLevel);	
		startLevel(nextLevelIdx);	
	}	

	public function initHeroLife(v) {
		herolife = maxherolife = v;
	}

	function startLevel(idx=-1, ?data:World_Level) {
		curLevelIdx = idx;
		fadeIn();

		// Cleanup
		if( level!=null )
			level.destroy();
		for(e in Entity.ALL)
			e.destroy();
		fx.clear();
		gc();
		tw.terminateWithoutCallbacks(camera.zoom);
		camera.zoom = 1;

		// End game
		if( data==null && idx>=world.levels.length ) {
			destroy();
			new Intro(true);
			return;
		}

		// Init
		level = new Level( data!=null ? data : world.levels[curLevelIdx] );
		level.attachMainEntities();
		initLevel();
		camera.trackTarget(hero, true);
		Process.resizeAll();
	}

	public function levelIdxFromName(v) {
		var lvlIdx = -1;
		var targetIdx = curLevelIdx;
		for (x in world.levels) {
			lvlIdx += 1;
			if (x.identifier == v)
				targetIdx = lvlIdx;
		}
		return targetIdx;
	}

	/**
		Called when the CastleDB changes on the disk, if hot-reloading is enabled in Boot.hx
	**/
	public function onCdbReload() {
	}

	/**
		Called when LDtk world changes on the disk, if hot-reloading is enabled in Boot.hx
	**/
	public function onLedReload() {
		world.parseJson( hxd.Res.world.world.entry.getText() );
		startLevel(curLevelIdx);
	}

	public function onRestart() {
		initHeroLife(5);
		startLevel(0);
	}

	public function onReload() {
		hero.hit(1,hero);
		startLevel(curLevelIdx);
	}

	override function onResize() {
		super.onResize();
		scroller.setScale(Const.SCALE);

		fadeMask.scaleX = w()/fadeMask.tile.width;
		fadeMask.scaleY = h()/fadeMask.tile.height;
	}



	public function initLevel() {
		Assets.SLIB.light0(0.5);

		// Doors
		delayer.addS("doors", ()->{
			for(e in en.Door.ALL)
				if( !e.destroyed && !e.needKey )
					e.setClosed(false);
		}, 0.2);


		// Entities callback
		for(e in Entity.ALL)
			if( !e.destroyed )
				e.initEntity();

		// Init entities
		level.attachLightEntities();

		// Timer
		cd.unset("autoSwitch"); // BUG cd ratio false
		if( en.Torch.any() ) {
			cd.setS("autoSwitch", Const.LIGHT_DURATION);
		}
		else {
			cd.setS("autoSwitch", Const.INFINITE);		
		}
	}

	public function getAutoSwitchS() return cd.getS("autoSwitch");
	public function getAutoSwitchRatio() return M.fclamp( cd.getRatio("autoSwitch"), 0, 1 );

	function gc() {
		if( Entity.GC==null || Entity.GC.length==0 )
			return;

		for(e in Entity.GC)
			e.dispose();
		Entity.GC = [];
	}

	override function onDispose() {
		super.onDispose();

		fx.destroy();
		for(e in Entity.ALL)
			e.destroy();
		gc();
	}


	/**
		Start a cumulative slow-motion effect that will affect `tmod` value in this Process
		and its children.

		@param sec Realtime second duration of this slowmo
		@param speedFactor Cumulative multiplier to the Process `tmod`
	**/
	public function addSlowMo(id:String, sec:Float, speedFactor=0.3) {
		if( slowMos.exists(id) ) {
			var s = slowMos.get(id);
			s.f = speedFactor;
			s.t = M.fmax(s.t, sec);
		}
		else
			slowMos.set(id, { id:id, t:sec, f:speedFactor });
	}


	function updateSlowMos() {
		// Timeout active slow-mos
		for(s in slowMos) {
			s.t -= utmod * 1/Const.FPS;
			if( s.t<=0 )
				slowMos.remove(s.id);
		}

		// Update game speed
		var targetGameSpeed = 1.0;
		for(s in slowMos)
			targetGameSpeed*=s.f;
		curGameSpeed += (targetGameSpeed-curGameSpeed) * (targetGameSpeed>curGameSpeed ? 0.2 : 0.6);

		if( M.fabs(curGameSpeed-targetGameSpeed)<=0.001 )
			curGameSpeed = targetGameSpeed;
	}


	/**
		Pause briefly the game for 1 frame: very useful for impactful moments,
		like when hitting an opponent in Street Fighter ;)
	**/
	public inline function stopFrame(t=0.2) {
		ucd.setS("stopFrame", t);
	}

	override function preUpdate() {
		super.preUpdate();

		for(e in Entity.ALL) if( !e.destroyed ) e.preUpdate();
	}

	override function postUpdate() {
		super.postUpdate();

		for(e in Entity.ALL) if( !e.destroyed ) e.postUpdate();
		for(e in Entity.ALL) if( !e.destroyed ) e.finalUpdate();
		gc();

		// Update slow-motions
		updateSlowMos();
		baseTimeMul = ( 0.2 + 0.8*curGameSpeed ) * ( ucd.has("stopFrame") ? 0.3 : 1 );
		Assets.tiles.tmod = tmod;
	}

	override function fixedUpdate() {
		super.fixedUpdate();

		for(e in Entity.ALL) if( !e.destroyed ) e.fixedUpdate();
	}

	override function update() {
		super.update();

		for(e in Entity.ALL) if( !e.destroyed ) e.update();

		if( !ui.Console.ME.isActive() && !ui.Modal.hasAny() ) {
			#if hl
			// Exit
			if( ca.isKeyboardPressed(Key.ESCAPE) )
				if( !cd.hasSetS("exitWarn",3) )
					trace(Lang.t._("Press ESCAPE again to exit."));
				else
					hxd.System.exit();
			#end

			#if debug
			if( ca.isKeyboardPressed(K.N) )
				nextLevel();

			if( ca.isKeyboardPressed(K.K) )
				for(e in en.Mob.ALL)
					e.destroy();
			#end

			// Restart
			// SHIFT+R or CTRL+R restart from level 0
			// R restart current level
			if( ca.selectPressed() ) {
				#if debug
				if( ca.isKeyboardDown(K.SHIFT) || ca.isKeyboardDown(K.CTRL) )
					startLevel(0);
				else
				#end
				startLevel(curLevelIdx);
			}
		}

		// Hero died - restart level
		if( !hero.isAlive() ) {
			onRestart();
		}
	}
}


