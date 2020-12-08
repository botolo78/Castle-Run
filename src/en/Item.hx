package en;

class Item extends Entity {
	public static var ALL : Array<Item> = [];
	public var type : Enum_ItemType;
	public var origin : Null<CPoint>;
	// public var inVault = false;
	public var shineColor = new h3d.Vector();

	public function new(x,y, t:Enum_ItemType) {
		super(x, y);
		ALL.push(this);
		gravityMul*=0.35;
		frictX = frictY = 0.96;

		type = t;
		origin = makePoint();
		cd.setS("pickLock",0.25);

		game.scroller.add(spr, Const.DP_BG);
		spr.set(switch type {
			case DoorKey: "itemKey";
		});

		switch type {
			case _:
		}
	}

	override function dispose() {
		super.dispose();
		ALL.remove(this);
	}

	override function onLand(fallCHei:Float) {
		super.onLand(fallCHei);

		if( fallCHei>=0.5 ) {
			dx*=0.5;
			dy = -0.1;
		}
	}

	public inline function isGrabbedByHero() return hero!=null && hero.isGrabbing(this);

	override function postUpdate() {
		super.postUpdate();
		if( hero.isGrabbing(this) ) {
			if( M.fabs(hero.dx)>=0.05 ) {
				spr.x += hero.dir*6;
				spr.y -= 5;
			}
			else
				spr.y-=Const.GRID*0.8;
		}
	}

	public function recalOffNarrow() {
		var old = cx;

		var dh = new dn.DecisionHelper( dn.Bresenham.getDisc(cx,cy, 3) );
		dh.keepOnly( (pt)->!level.hasCollision(pt.x,pt.y) && !level.hasCollision(pt.x,pt.y-1) );
		dh.score( (pt)->-distCaseFree(pt.x,pt.y) );
		dh.useBest( (pt)->setPosCase(pt.x, pt.y) );

		cancelVelocities();
		dx = (cx>old?1:-1) * 0.05;
		dy = -0.12;
		xr = cx>old ? 0.1 : 0.9;
	}

	override function update() {
		super.update();

		if( !isGrabbedByHero() && level.hasCollision(cx,cy-1) && level.hasCollision(cx,cy+1) )
			recalOffNarrow();

		if( distCase(hero)<=0.9 && !hero.isGrabbingAnything() && !cd.has("pickLock") ) {			
			switch type {

			case DoorKey:
				Assets.SLIB.pick2(0.5);
				hero.grabItem(this);
			}
		}
	}
}