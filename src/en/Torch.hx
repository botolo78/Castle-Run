package en;

class Torch extends Entity {
	public static var ALL : Array<Torch> = [];

	var eternal = false;
	public function new(e:World.Entity_Torch) {
		super(e.cx, e.cy);
		eternal = e.f_eternal;
		ALL.push(this);
		gravityMul = 0;
		game.scroller.add(spr, Const.DP_BG);

		spr.set("torchOff");
	}

	public static function any() {
		for(e in ALL) 
			if( e.isAlive() && !e.eternal )
				return true;
		return false;
	}

	override function initEntity() {
		super.initEntity();
		fx.torchLightOn(footX, footY-10);
	}	

	override function dispose() {
		super.dispose();
		ALL.remove(this);
	}

	override function postUpdate() {
		super.postUpdate();

		spr.filter = null;
		spr.alpha = 0.3;
		if( !cd.hasSetS("fx",0.1) )
			fx.torchFlame(footX, footY-10, game.getAutoSwitchRatio());
	}

	override function update() {
		super.update();
	}
}