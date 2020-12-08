package en;

import ldtk.Level.NeighbourDir;
import haxe.display.Position;

class Hero extends Entity {
	public var herolife(get,set) : Int;  
	var ca : dn.heaps.Controller.ControllerAccess;

	var shadow : h2d.filter.DropShadow;

	function get_herolife() {
		return Game.HEROLIFE;
	}

	function set_herolife(x : Int) {
		return Game.HEROLIFE = x;
	}

	public function new(e:Entity_Hero) {
		super(e.cx, e.cy);
		ca = Main.ME.controller.createAccess("hero");
		ca.setLeftDeadZone(0.2);
		circularCollisions = false;
		get_herolife();


		shadow = new h2d.filter.DropShadow(4, 0, 0x0, 0.3); // overriden in postUpdate()!
		spr.filter = new h2d.filter.Group([
			new dn.heaps.filter.PixelOutline(),
			shadow,
		]);

		spr.anim.registerStateAnim("heroJumpUp",15, ()->!climbing && !onGround && dy<=0.05 );
		spr.anim.registerStateAnim("heroJumpDown",15, 0.9, ()->!climbing && !onGround && dy>0.05 );

		spr.anim.registerStateAnim("heroClimb",11, 2, ()->climbing && ( M.fabs(dy)>=0.05*tmod || cd.has("climbAnim") ) );
		spr.anim.registerStateAnim("heroClimbIdle",10, ()->climbing);

		spr.anim.registerStateAnim("heroCrouchRun",6, 2, ()->M.fabs(dx)>=0.05*tmod && isCrouching() );
		spr.anim.registerStateAnim("heroRun",5, 2, ()->M.fabs(dx)>=0.05*tmod );

		spr.anim.registerStateAnim("heroIdleGrab",1, ()->!isCrouching() && isGrabbingAnything());
		spr.anim.registerStateAnim("heroCrouchIdle",0, ()->isCrouching());
		spr.anim.registerStateAnim("heroIdle",0, ()->!isCrouching());

		spr.anim.registerTransitions(["heroIdle","heroIdleGrab"],["heroRun"],"heroIdleRun", 1);
	}

	override function onDamage(dmg:Int, from:Entity) {
		super.onDamage(dmg, from);
		cancelVelocities();
		if( from!=null )
			bump(from.dirTo(this)*0.2, -0.2);
		setSquashX(0.5);
		lockControlS(0.3);
		fx.flashBangS(0xff0000,0.2, 1);
		camera.shakeS(0.5,0.5);
		hud.invalidate();
		game.stopFrame(); //slowmo
	}


	override function hit(dmg:Int, from:Null<Entity>) {
		if( !isAlive() || dmg<=0 )
			return;

		var updated_herolife = herolife-dmg;
		set_herolife(updated_herolife);
		lastDmgSource = from;
		onDamage(dmg, from);
		if( herolife<=0 )
			onDie();
	}

	override function onDie() {
		set_herolife(5);
		destroy();
	}

	override function dispose() {
		super.dispose();
		ca.dispose();
	}

	override function startClimbing() {
		super.startClimbing();
		Assets.SLIB.ladder0(0.4);
		cd.unset("jumpForce");
		cd.unset("jumpExtra");
	}

	override function onLand(fallCHei:Float) {
		super.onLand(fallCHei);

		if( fallCHei>=3 )
			Assets.SLIB.land0(1);
		else
			Assets.SLIB.land1(0.5 * M.fmin(1,fallCHei/2));

		var impact = M.fmin(1, fallCHei/6);
		dx *= (1-impact)*0.5;
		game.camera.bump(0, 3*impact);
		setSquashY(1-impact*0.7);

		if( fallCHei>=9 ) {
			lockControlS(0.3);
			game.camera.shakeS(1,0.3);
			cd.setS("heavyLand",0.3);
		}
		else if( fallCHei>=3 )
			lockControlS(0.03*impact);
	}

	public inline function isCrouching() {
		return isAlive() && ( level.hasCollision(cx,cy-1) && level.hasCollision(cx,cy+1) || cd.has("heavyLand") );
	}

	override function postUpdate() {
		super.postUpdate();
		spr.anim.setGlobalSpeed( 0.25 );

		shadow.angle = dir==1 ? 0 : M.PI;
		shadow.distance = 2;
		if( climbing ) {
			shadow.distance = 1;
			shadow.alpha = 0.2;
		}
		else if( level.hasSky(cx,cy) || level.hasSky(cx,cy-1) )
			shadow.alpha = 0;
		else 
			shadow.alpha = 0.1;
	}

	override function update() {
		super.update();
		var spd = Const.HERO_BASE_SPEED;


		if( onGround || climbing ) {
			cd.setS("onGroundRecently",0.1);
			cd.setS("airControl",10);
		}

		// Walk
		if( !controlsLocked() && ca.leftDist() > 0 ) {
			if( !climbing )
				dx += Math.cos( ca.leftAngle() ) * ca.leftDist() * spd * ( 0.4+0.6*cd.getRatio("airControl") ) * tmod;
			var old = dir;
			dir = M.sign( Math.cos(ca.leftAngle()) );
			if( old!=dir && !isCrouching() && !climbing )
				spr.anim.playOverlap("heroTurn", 0.66);
		}
		else
			dx*=Math.pow(0.8,tmod);

		// Jump
		var jumpKeyboardDown = ca.isKeyboardDown(K.Z) || ca.isKeyboardDown(K.W) || ca.isKeyboardDown(K.UP);
		if( !controlsLocked() && ca.aPressed() && !isCrouching() && ( !climbing && cd.has("onGroundRecently") || climbing && !jumpKeyboardDown ) ) {
			if( climbing ) {
				stopClimbing();
				cd.setS("climbLock",0.2);
				dx = dir*0.1;
				if( dy>0 )
					dy = 0.2;
				else {
					dy = -0.05;
					cd.setS("jumpForce",0.1);
					cd.setS("jumpExtra",0.1);
				}
			}
			else {
				setSquashX(0.7); // 70% width size while jumping
				dy = -0.1; // Jump distance
				cd.setS("jumpForce",0.3);
				cd.setS("jumpExtra",0.1);
			}
		}
		else if( cd.has("jumpExtra") && ca.aDown() )
			dy-=0.04*tmod;

		if( cd.has("jumpForce") && ca.aDown() )
			dy -= 0.05 * cd.getRatio("jumpForce") * tmod;

		// Throw item
		if( ca.xPressed() ) {
			var e = dropItem();
			if( e!=null ) {
				e.cd.setS("pickLock",0.2);
				e.dx = dir*0.45;
				e.dy = -0.15;
				e.cd.setS("recentThrow",1);
				bump(dir*0.05, 0);
				spr.anim.play("heroThrow");
				lockControlS(0.4);
				stopClimbing();
			}
		}

		if( !climbing && !cd.has("climbLock") && !controlsLocked() && ca.leftDist()>0 ) {
			// Grab ladder up
			if( M.radDistance(ca.leftAngle(),-M.PIHALF)<=M.PIHALF*0.5 && level.hasLadder(cx,cy) ) {
				startClimbing();
				setSquashX(0.6);
				dy-=0.2;
			}
			// Grab ladder down
			if( M.radDistance(ca.leftAngle(),M.PIHALF)<=M.PIHALF*0.5 && level.hasLadder(cx,cy+1) ) {
				startClimbing();
				cy++;
				yr = 0.1;
				setSquashY(0.6);
				dy=0.2;
			}
		}

		// Lost ladder
		if( climbing && !level.hasLadder(cx,cy) )
			stopClimbing();

		// Reach ladder top
		if( climbing && dy<0 && !level.hasLadder(cx,cy-1) && yr<=0.7 ) {
			stopClimbing();
			dy = -0.2;
			yr = 0.2;
			cd.setS("climbLock",0.2);
		}

		if( climbing )
			xr += (0.5-xr)*0.1;

		// Reach ladder bottom
		if( climbing && dy>0 && !level.hasLadder(cx,cy+1) ) {
			stopClimbing();
			dy = 0.1;
			cd.setS("climbLock",0.2);
		}

		// Climb movement
		if( climbing && ca.leftDist()>0 && !cd.hasSetS("climbStep", 0.2) ) {
			dy += Math.sin(ca.leftAngle()) * spd * 7; // no tmod because it's a step movement
			cd.setS("climbAnim", 0.2);
		}

		// Hop
		if( !controlsLocked() && yr<0.5 && dy>0 && ca.leftDist()>0 ) {
			if( xr>=0.5 && level.hasMark(GrabRight,cx,cy) && M.radDistance(ca.leftAngle(),0)<=M.PIHALF*0.7 && !level.hasCollision(cx+1,cy-1) ) {
				yr = M.fmin(0.4,yr);
				dy = -0.2;
				dx+=0.2;
			}
			if( xr<=0.5 && level.hasMark(GrabLeft,cx,cy) && M.radDistance(ca.leftAngle(),M.PI)<=M.PIHALF*0.7 && !level.hasCollision(cx-1,cy-1) ) {
				yr = M.fmin(0.4,yr);
				dy = -0.2;
				dx-=0.2;
			}
		}

		// Attack
		if( !controlsLocked() && ca.bPressed() && !isGrabbingAnything() || ca.isKeyboardPressed(K.ALT) && !isGrabbingAnything() && !isCrouching()) {
			setSquashY(rnd(0.8,1));
			spr.anim.play("heroAtkA");
			fx.slash(centerX+dir*3, centerY, dir);
			camera.bump(dir*rnd(1,2), 0);
			camera.shakeS(0.3,0.1);
			

			var a = [
				Assets.SLIB.hit8,
				Assets.SLIB.hit9,
			];
			a[Std.random(a.length)](0.7);
			var a = [
				Assets.SLIB.hit6,
				Assets.SLIB.hit7,
			];
			a[Std.random(a.length)](0.6);

			for(e in en.Mob.ALL) {
				if( e.isAlive() && distCaseX(e)<=2 && footY>=e.footY-Const.GRID*1 && footY<=e.footY+Const.GRID*0.5) {
				e.hit(1,hero);
				bump(-dirTo(e)*rnd(0.03,0.06), 0);
				e.bump(dirTo(e)*rnd(0.06,0.12), -rnd(0.04,0.08));
				// e.bump(-dirTo(hero)*0.2, -0.1);
				fx.gibs(e.centerX, e.centerY, dirTo(e));
				}
			}

		}


		// Drop item while crouching
		if( isGrabbingAnything() && isCrouching() ) {
			var e = dropItem();
			e.recalOffNarrow();
		}

		if( onGround || dy<0 )
			cd.setS("fallSquash", 1);
		if( !onGround && dy>0 )
			setSquashX( 1 - 0.1 * (1-cd.getRatio("fallSquash")) );

		#if debug
		// debug( M.pretty(hxd.Timer.fps(),1) );
		#end
	}
}