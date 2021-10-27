package;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;

import CustomControlsState;
import ui.FlxVirtualPad;

using StringTools;

// TO DO: Redo the menu creation system for not being as dumb
class OptionsState extends MusicBeatState
{
	var options:Array<String> = ['Configuracoes', 'Estilo de nota', 'Controles Mobile', 'Controles para Teclado'];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;

	override function create() {
		#if desktop
		DiscordClient.changePresence("Options Menu", null);
		#end

		menuBG = new FlxSprite().loadGraphic(Paths.image('menuBGBlue'));
		menuBG.color = 0xFFea71fd;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = ClientPrefs.globalAntialiasing;
		add(menuBG);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionText:Alphabet = new Alphabet(0, 0, options[i], true, false);
			optionText.screenCenter();
			optionText.y += (100 * (i - (options.length / 2))) + 50;
			grpOptions.add(optionText);
		}
		changeSelection();

		addVirtualPad(FULL, A_B);

		super.create();
	}

	override function closeSubState() {
		super.closeSubState();
		ClientPrefs.saveSettings();
		changeSelection();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (controls.UI_UP_P) {
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P) {
			changeSelection(1);
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (controls.ACCEPT) {
			for (item in grpOptions.members) {
				item.alpha = 0;
			}

			switch(options[curSelected]) {
				case 'Configuracoes':
					openSubState(new PreferencesSubstate());

				case 'Estilo de nota':
					openSubState(new NotesSubstate());

				case 'Controles Mobile':
					MusicBeatState.switchState(new CustomControlsState());

				case 'Controles para Teclado':
					openSubState(new ControlsSubstate());

			}
		}
	}
	
	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0) {
				item.alpha = 1;
			}
		}
	}
}



class NotesSubstate extends MusicBeatSubstate
{
	private static var curSelected:Int = 0;
	private static var typeSelected:Int = 0;
	private var grpNumbers:FlxTypedGroup<Alphabet>;
	private var grpNotes:FlxTypedGroup<FlxSprite>;
	private var shaderArray:Array<ColorSwap> = [];
	var curValue:Float = 0;
	var holdTime:Float = 0;
	var hsvText:Alphabet;
	var nextAccept:Int = 5;

	var posX = 250;
	public function new() {
		super();

		grpNotes = new FlxTypedGroup<FlxSprite>();
		add(grpNotes);
		grpNumbers = new FlxTypedGroup<Alphabet>();
		add(grpNumbers);

		for (i in 0...ClientPrefs.arrowHSV.length) {
			var yPos:Float = (165 * i) + 35;
			for (j in 0...3) {
				var optionText:Alphabet = new Alphabet(0, yPos, Std.string(ClientPrefs.arrowHSV[i][j]));
				optionText.x = posX + (225 * j) + 100 - ((optionText.lettersArray.length * 90) / 2);
				grpNumbers.add(optionText);
			}

			var note:FlxSprite = new FlxSprite(posX - 70, yPos);
			note.frames = Paths.getSparrowAtlas('NOTE_assets');
			switch(i) {
				case 0:
					note.animation.addByPrefix('idle', 'purple0');
				case 1:
					note.animation.addByPrefix('idle', 'blue0');
				case 2:
					note.animation.addByPrefix('idle', 'green0');
				case 3:
					note.animation.addByPrefix('idle', 'red0');
			}
			note.animation.play('idle');
			note.antialiasing = ClientPrefs.globalAntialiasing;
			grpNotes.add(note);

			var newShader:ColorSwap = new ColorSwap();
			note.shader = newShader.shader;
			newShader.hue = ClientPrefs.arrowHSV[i][0] / 360;
			newShader.saturation = ClientPrefs.arrowHSV[i][1] / 100;
			newShader.brightness = ClientPrefs.arrowHSV[i][2] / 100;
			shaderArray.push(newShader);
		}
		hsvText = new Alphabet(0, 0, "Hue    Saturation  Brightness", false, false, 0, 0.65);
		add(hsvText);
		
		#if mobileC
        addVirtualPad(FULL, A_B);
        #end
		
		changeSelection();
	}

	var changingNote:Bool = false;
	var hsvTextOffsets:Array<Float> = [240, 90];
	override function update(elapsed:Float) {
		if(changingNote) {
			if(holdTime < 0.5) {
				if(controls.UI_LEFT_P) {
					updateValue(-1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.UI_RIGHT_P) {
					updateValue(1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				} else if(controls.RESET) {
					resetValue(curSelected, typeSelected);
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					holdTime = 0;
				} else if(controls.UI_LEFT || controls.UI_RIGHT) {
					holdTime += elapsed;
				}
			} else {
				var add:Float = 90;
				switch(typeSelected) {
					case 1 | 2: add = 50;
				}
				if(controls.UI_LEFT) {
					updateValue(elapsed * -add);
				} else if(controls.UI_RIGHT) {
					updateValue(elapsed * add);
				}
				if(controls.UI_LEFT_R || controls.UI_RIGHT_R) {
					FlxG.sound.play(Paths.sound('scrollMenu'));
					holdTime = 0;
				}
			}
		} else {
			if (controls.UI_UP_P) {
				changeSelection(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_LEFT_P) {
				changeType(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.UI_RIGHT_P) {
				changeType(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if(controls.RESET) {
				for (i in 0...3) {
					resetValue(curSelected, i);
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}
			if (controls.ACCEPT && nextAccept <= 0) {
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changingNote = true;
				holdTime = 0;
				for (i in 0...grpNumbers.length) {
					var item = grpNumbers.members[i];
					item.alpha = 0;
					if ((curSelected * 3) + typeSelected == i) {
						item.alpha = 1;
					}
				}
				for (i in 0...grpNotes.length) {
					var item = grpNotes.members[i];
					item.alpha = 0;
					if (curSelected == i) {
						item.alpha = 1;
					}
				}
				super.update(elapsed);
				return;
			}
		}

		var lerpVal:Float = CoolUtil.boundTo(elapsed * 9.6, 0, 1);
		for (i in 0...grpNotes.length) {
			var item = grpNotes.members[i];
			var intendedPos:Float = posX - 70;
			if (curSelected == i) {
				item.x = FlxMath.lerp(item.x, intendedPos + 100, lerpVal);
			} else {
				item.x = FlxMath.lerp(item.x, intendedPos, lerpVal);
			}
			for (j in 0...3) {
				var item2 = grpNumbers.members[(i * 3) + j];
				item2.x = item.x + 265 + (225 * (j % 3)) - (30 * item2.lettersArray.length) / 2;
				if(ClientPrefs.arrowHSV[i][j] < 0) {
					item2.x -= 20;
				}
			}

			if(curSelected == i) {
				hsvText.setPosition(item.x + hsvTextOffsets[0], item.y - hsvTextOffsets[1]);
			}
		}

		if (controls.BACK || (changingNote && controls.ACCEPT)) {
			changeSelection();
			if(!changingNote) {
				grpNumbers.forEachAlive(function(spr:Alphabet) {
					spr.alpha = 0;
				});
				grpNotes.forEachAlive(function(spr:FlxSprite) {
					spr.alpha = 0;
				});
				close();
			}
			changingNote = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = ClientPrefs.arrowHSV.length-1;
		if (curSelected >= ClientPrefs.arrowHSV.length)
			curSelected = 0;

		curValue = ClientPrefs.arrowHSV[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
		for (i in 0...grpNotes.length) {
			var item = grpNotes.members[i];
			item.alpha = 0.6;
			item.scale.set(1, 1);
			if (curSelected == i) {
				item.alpha = 1;
				item.scale.set(1.2, 1.2);
				hsvText.setPosition(item.x + hsvTextOffsets[0], item.y - hsvTextOffsets[1]);
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeType(change:Int = 0) {
		typeSelected += change;
		if (typeSelected < 0)
			typeSelected = 2;
		if (typeSelected > 2)
			typeSelected = 0;

		curValue = ClientPrefs.arrowHSV[curSelected][typeSelected];
		updateValue();

		for (i in 0...grpNumbers.length) {
			var item = grpNumbers.members[i];
			item.alpha = 0.6;
			if ((curSelected * 3) + typeSelected == i) {
				item.alpha = 1;
			}
		}
	}

	function resetValue(selected:Int, type:Int) {
		curValue = 0;
		ClientPrefs.arrowHSV[selected][type] = 0;
		switch(type) {
			case 0: shaderArray[selected].hue = 0;
			case 1: shaderArray[selected].saturation = 0;
			case 2: shaderArray[selected].brightness = 0;
		}
		grpNumbers.members[(selected * 3) + type].changeText('0');
	}
	function updateValue(change:Float = 0) {
		curValue += change;
		var roundedValue:Int = Math.round(curValue);
		var max:Float = 180;
		switch(typeSelected) {
			case 1 | 2: max = 100;
		}

		if(roundedValue < -max) {
			curValue = -max;
		} else if(roundedValue > max) {
			curValue = max;
		}
		roundedValue = Math.round(curValue);
		ClientPrefs.arrowHSV[curSelected][typeSelected] = roundedValue;

		switch(typeSelected) {
			case 0: shaderArray[curSelected].hue = roundedValue / 360;
			case 1: shaderArray[curSelected].saturation = roundedValue / 100;
			case 2: shaderArray[curSelected].brightness = roundedValue / 100;
		}
		grpNumbers.members[(curSelected * 3) + typeSelected].changeText(Std.string(roundedValue));
	}
}



class ControlsSubstate extends MusicBeatSubstate {
	private static var curSelected:Int = 1;
	private static var curAlt:Bool = false;

	private static var defaultKey:String = 'Reset to Default Keys';

	var optionShit:Array<String> = [
		'NOTES',
		ClientPrefs.keyBinds[0][1],
		ClientPrefs.keyBinds[1][1],
		ClientPrefs.keyBinds[2][1],
		ClientPrefs.keyBinds[3][1],
		'',
		'UI',
		ClientPrefs.keyBinds[4][1],
		ClientPrefs.keyBinds[5][1],
		ClientPrefs.keyBinds[6][1],
		ClientPrefs.keyBinds[7][1],
		'',
		ClientPrefs.keyBinds[8][1],
		ClientPrefs.keyBinds[9][1],
		ClientPrefs.keyBinds[10][1],
		ClientPrefs.keyBinds[11][1],
		'',
		defaultKey];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var grpInputs:Array<AttachedText> = [];
	private var controlArray:Array<FlxKey> = [];
	var rebindingKey:Int = -1;
	var nextAccept:Int = 5;

	public function new() {
		super();
		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		controlArray = ClientPrefs.lastControls.copy();
		for (i in 0...optionShit.length) {
			var isCentered:Bool = false;
			var isDefaultKey:Bool = (optionShit[i] == defaultKey);
			if(unselectableCheck(i, true)) {
				isCentered = true;
			}

			var optionText:Alphabet = new Alphabet(0, (10 * i), optionShit[i], (!isCentered || isDefaultKey), false);
			optionText.isMenuItem = true;
			if(isCentered) {
				optionText.screenCenter(X);
				optionText.forceX = optionText.x;
				optionText.yAdd = -55;
			} else {
				optionText.forceX = 200;
			}
			optionText.yMult = 60;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(!isCentered) {
				addBindTexts(optionText);
			}
		}

		#if mobileC
		addVirtualPad(NONE, A_B); //CAUTELOSOS MOMENT
		#end

		changeSelection();
	}

	var leaving:Bool = false;
	var bindingTime:Float = 0;
	override function update(elapsed:Float) {
		if(rebindingKey < 0) {
			if (controls.UI_UP_P) {
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
			}
			if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
				changeAlt();
			}

			if (controls.BACK) {
				ClientPrefs.reloadControls(controlArray);
				grpOptions.forEachAlive(function(spr:Alphabet) {
					spr.alpha = 0;
				});
				for (i in 0...grpInputs.length) {
					var spr:AttachedText = grpInputs[i];
					if(spr != null) {
						spr.alpha = 0;
					}
				}
				close();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}

			if(controls.ACCEPT && nextAccept <= 0) {
				if(optionShit[curSelected] == defaultKey) {
					controlArray = ClientPrefs.defaultKeys.copy();
					reloadKeys();
					changeSelection();
					FlxG.sound.play(Paths.sound('confirmMenu'));
				} else {
					bindingTime = 0;
					rebindingKey = getSelectedKey();
					if(rebindingKey > -1) {
						grpInputs[rebindingKey].visible = false;
						FlxG.sound.play(Paths.sound('scrollMenu'));
					} else {
						FlxG.log.warn('Error! No input found/badly configured');
						FlxG.sound.play(Paths.sound('cancelMenu'));
					}
				}
			}
		} else {
			var keyPressed:Int = FlxG.keys.firstJustPressed();
			if (keyPressed > -1) {
				controlArray[rebindingKey] = keyPressed;
				var opposite:Int = rebindingKey + (rebindingKey % 2 == 1 ? -1 : 1);
				trace('Rebinded key with ID: ' + rebindingKey + ', Opposite is: ' + opposite);
				if(controlArray[opposite] == controlArray[rebindingKey]) {
					controlArray[opposite] = NONE;
				}

				reloadKeys();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				rebindingKey = -1;
			}

			bindingTime += elapsed;
			if(bindingTime > 5) {
				grpInputs[rebindingKey].visible = true;
				FlxG.sound.play(Paths.sound('scrollMenu'));
				rebindingKey = -1;
				bindingTime = 0;
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}
	
	function changeSelection(change:Int = 0) {
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = optionShit.length - 1;
			if (curSelected >= optionShit.length)
				curSelected = 0;
		} while(unselectableCheck(curSelected));

		var bullShit:Int = 0;

		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
					for (i in 0...grpInputs.length) {
						if(grpInputs[i].sprTracker == item && grpInputs[i].isAlt == curAlt) {
							grpInputs[i].alpha = 1;
						}
					}
				}
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeAlt() {
		curAlt = !curAlt;
		for (i in 0...grpInputs.length) {
			if(grpInputs[i].sprTracker == grpOptions.members[curSelected]) {
				grpInputs[i].alpha = 0.6;
				if(grpInputs[i].isAlt == curAlt) {
					grpInputs[i].alpha = 1;
				}
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	private function unselectableCheck(num:Int, ?checkDefaultKey:Bool = false):Bool {
		if(optionShit[num] == defaultKey) {
			return checkDefaultKey;
		}

		for (i in 0...ClientPrefs.keyBinds.length) {
			if(ClientPrefs.keyBinds[i][1] == optionShit[num]) {
				return false;
			}
		}
		return true;
	}

	private function getSelectedKey():Int {
		var altValue:Int = (curAlt ? 1 : 0);
		for (i in 0...ClientPrefs.keyBinds.length) {
			if(ClientPrefs.keyBinds[i][1] == optionShit[curSelected]) {
				return i*2 + altValue;
			}
		}
		return -1;
	}

	private function addBindTexts(optionText:Alphabet) {
		var text1 = new AttachedText(InputFormatter.getKeyName(controlArray[grpInputs.length]), 400, -55);
		text1.setPosition(optionText.x + 400, optionText.y - 55);
		text1.sprTracker = optionText;
		grpInputs.push(text1);
		add(text1);

		var text2 = new AttachedText(InputFormatter.getKeyName(controlArray[grpInputs.length]), 650, -55);
		text2.setPosition(optionText.x + 650, optionText.y - 55);
		text2.sprTracker = optionText;
		text2.isAlt = true;
		grpInputs.push(text2);
		add(text2);
	}

	function reloadKeys() {
		while(grpInputs.length > 0) {
			var item:AttachedText = grpInputs[0];
			grpInputs.remove(item);
			remove(item);
		}

		for (i in 0...grpOptions.length) {
			if(!unselectableCheck(i, true)) {
				addBindTexts(grpOptions.members[i]);
			}
		}


		var bullShit:Int = 0;
		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
					for (i in 0...grpInputs.length) {
						if(grpInputs[i].sprTracker == item && grpInputs[i].isAlt == curAlt) {
							grpInputs[i].alpha = 1;
						}
					}
				}
			}
		}
	}
}



class PreferencesSubstate extends MusicBeatSubstate
{
	private static var curSelected:Int = 0;
	static var unselectableOptions:Array<String> = [
		'GRAFICOS',
		'GAMEPLAY'
	];
	static var noCheckbox:Array<String> = [
		'FPS',
		'Delay na nota'
	];

	static var options:Array<String> = [
		'GRAFICOS',
		'Baixa Qualidade',
		'Anti-Aliasing',
		'Salvar imagens em cache',
		#if !html5
		'FPS', //Apparently 120FPS isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		#end
		'GAMEPLAY',
		'Som de OSU',
		'Downscroll',
		'Middlescroll',
		'Delay na nota',
		'Efeito Splash na nota',
		'Ocultar HUD',
		'Ocultar tempo de musica',
		'Luzes Piscantes',
		'Cenarios Visiveis',
		'Pular Cutscenes',
		'Pular dialogos',
		'Remover GF',
		'Efeitos de camera'
		,'FPS Visivel'
	];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxArray:Array<CheckboxThingie> = [];
	private var checkboxNumber:Array<Int> = [];
	private var grpTexts:FlxTypedGroup<AttachedText>;
	private var textNumber:Array<Int> = [];

	private var characterLayer:FlxTypedGroup<Character>;
	private var showCharacter:Character = null;
	private var descText:FlxText;

	public function new()
	{
		super();
		characterLayer = new FlxTypedGroup<Character>();
		add(characterLayer);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		for (i in 0...options.length)
		{
			var isCentered:Bool = unselectableCheck(i);
			var optionText:Alphabet = new Alphabet(0, 70 * i, options[i], false, false);
			optionText.isMenuItem = true;
			if(isCentered) {
				optionText.screenCenter(X);
				optionText.forceX = optionText.x;
			} else {
				optionText.x += 300;
				optionText.forceX = 300;
			}
			optionText.yMult = 90;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(!isCentered) {
				var useCheckbox:Bool = true;
				for (j in 0...noCheckbox.length) {
					if(options[i] == noCheckbox[j]) {
						useCheckbox = false;
						break;
					}
				}

				if(useCheckbox) {
					var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, false);
					checkbox.sprTracker = optionText;
					checkboxArray.push(checkbox);
					checkboxNumber.push(i);
					add(checkbox);
				} else {
					var valueText:AttachedText = new AttachedText('0', optionText.width + 80);
					valueText.sprTracker = optionText;
					grpTexts.add(valueText);
					textNumber.push(i);
				}
			}
		}

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...options.length) {
			if(!unselectableCheck(i)) {
				curSelected = i;
				break;
			}
		}
		
		#if mobileC
        addVirtualPad(FULL, A_B);
        #end
		
		changeSelection();
		reloadValues();
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		if (controls.BACK) {
			grpOptions.forEachAlive(function(spr:Alphabet) {
				spr.alpha = 0;
			});
			grpTexts.forEachAlive(function(spr:AttachedText) {
				spr.alpha = 0;
			});
			for (i in 0...checkboxArray.length) {
				var spr:CheckboxThingie = checkboxArray[i];
				if(spr != null) {
					spr.alpha = 0;
				}
			}
			if(showCharacter != null) {
				showCharacter.alpha = 0;
			}
			descText.alpha = 0;
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		var usesCheckbox = true;
		for (i in 0...noCheckbox.length) {
			if(options[curSelected] == noCheckbox[i]) {
				usesCheckbox = false;
				break;
			}
		}

		if(usesCheckbox) {
			if(controls.ACCEPT && nextAccept <= 0) {
				switch(options[curSelected]) {
					case 'FPS Visivel':
						ClientPrefs.showFPS = !ClientPrefs.showFPS;
						if(Main.fpsVar != null)
							Main.fpsVar.visible = ClientPrefs.showFPS;

					case 'Baixa Qualidade':
						ClientPrefs.lowQuality = !ClientPrefs.lowQuality;

					case 'Anti-Aliasing':
						ClientPrefs.globalAntialiasing = !ClientPrefs.globalAntialiasing;
						showCharacter.antialiasing = ClientPrefs.globalAntialiasing;
						for (item in grpOptions) {
							item.antialiasing = ClientPrefs.globalAntialiasing;
						}
						for (i in 0...checkboxArray.length) {
							var spr:CheckboxThingie = checkboxArray[i];
							if(spr != null) {
								spr.antialiasing = ClientPrefs.globalAntialiasing;
							}
						}
						OptionsState.menuBG.antialiasing = ClientPrefs.globalAntialiasing;

					case 'Efeito Splash na nota':
						ClientPrefs.noteSplashes = !ClientPrefs.noteSplashes;

					case 'Luzes Piscantes':
						ClientPrefs.flashing = !ClientPrefs.flashing;

					case 'Cenarios Visiveis':
						ClientPrefs.cenoptim = !ClientPrefs.cenoptim;

					case 'Pular Cutscenes':
						ClientPrefs.dacut = !ClientPrefs.dacut;

					case 'Pular dialogos':
						ClientPrefs.dadia = !ClientPrefs.dadia;


					case 'Som de OSU':
						ClientPrefs.violence = !ClientPrefs.violence;

					case 'Swearing':
						ClientPrefs.cursing = !ClientPrefs.cursing;

					case 'Downscroll':
						ClientPrefs.downScroll = !ClientPrefs.downScroll;

					case 'Middlescroll':
						ClientPrefs.middleScroll = !ClientPrefs.middleScroll;

					case 'Ghost Tapping':
						ClientPrefs.ghostTapping = !ClientPrefs.ghostTapping;

					case 'Efeitos de camera':
						ClientPrefs.camZooms = !ClientPrefs.camZooms;
					case 'Remover GF':
						ClientPrefs.dagf = !ClientPrefs.dagf;

					case 'Ocultar HUD':
						ClientPrefs.hideHud = !ClientPrefs.hideHud;

					case 'Salvar imagens em cache':
						ClientPrefs.imagesPersist = !ClientPrefs.imagesPersist;
						FlxGraphic.defaultPersist = ClientPrefs.imagesPersist;

					case 'Ocultar tempo de musica':
						ClientPrefs.hideTime = !ClientPrefs.hideTime;
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
				reloadValues();
			}
		} else {
			if(controls.UI_LEFT || controls.UI_RIGHT) {
				var add:Int = controls.UI_LEFT ? -1 : 1;
				if(holdTime > 0.5 || controls.UI_LEFT_P || controls.UI_RIGHT_P)
				switch(options[curSelected]) {
					case 'FPS':
						ClientPrefs.framerate += add;
						if(ClientPrefs.framerate < 30) ClientPrefs.framerate = 30;
						else if(ClientPrefs.framerate > 240) ClientPrefs.framerate = 240;

						if(ClientPrefs.framerate > FlxG.drawFramerate) {
							FlxG.updateFramerate = ClientPrefs.framerate;
							FlxG.drawFramerate = ClientPrefs.framerate;
						} else {
							FlxG.drawFramerate = ClientPrefs.framerate;
							FlxG.updateFramerate = ClientPrefs.framerate;
						}
					case 'Delay na nota':
						var mult:Int = 1;
						if(holdTime > 1.5) { //Double speed after 1.5 seconds holding
							mult = 2;
						}
						ClientPrefs.noteOffset += add * mult;
						if(ClientPrefs.noteOffset < 0) ClientPrefs.noteOffset = 0;
						else if(ClientPrefs.noteOffset > 500) ClientPrefs.noteOffset = 500;
				}
				reloadValues();

				if(holdTime <= 0) FlxG.sound.play(Paths.sound('scrollMenu'));
				holdTime += elapsed;
			} else {
				holdTime = 0;
			}
		}

		if(showCharacter != null && showCharacter.animation.curAnim.finished) {
			showCharacter.dance();
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}
	
	function changeSelection(change:Int = 0)
	{
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = options.length - 1;
			if (curSelected >= options.length)
				curSelected = 0;
		} while(unselectableCheck(curSelected));

		var daText:String = '';
		switch(options[curSelected]) {
			case 'FPS':
				daText = "Alto explicativo eu acho... :ricardo_reverso: \nPara ajudar a vida dos celulares fracos\n por padrao deixamos como 60fps";
			case 'Delay na nota':
				daText = "Muda o quao tarde uma nota aparece.\nUtil para os mano do fone diferenciado";
			case 'FPS Visivel':
				daText = "If unchecked, hides FPS Counter.";
			case 'Baixa Qualidade':
				daText = "se desmarcardo, desativa os detalhes do cenario,\naumenta a velocidade de carregado e a performance\n mas a custo de ver o Ycaro morrendo.";
			case 'Salvar imagens em cache':
				daText = "Se marcado, os sprites permanecerao na memoria\neconomiza a memoria e evita crashes na gameplay,\nmas aumenta o tempo de carregamento (relaxa, nao somos o Peppy)\n nao e farpas se for true : D";
			case 'Anti-Aliasing':
				daText = "se desmarcado, deixa o antialiasing desativado, aumenta a performance\nMAS os sprites parecem meio sus (mas quem liga?)";
			case 'Downscroll':
				daText = "Auto-explicativo certo? Nexxy, Max Extreme e Marcelo (PQC)?";
			case 'Middlescroll':
				daText = "Se desmarcado, as setas do oponente somem e suas setas passam a vir pelo meio";
			case 'Ghost Tapping':
				daText = "Se desmarcado, o jogo fica mais hardcore\nresumindo, tu perde vida por errar fiote.";
			case 'Swearing':
				daText = "Sei la que disgrama e isso";
			case 'Som de OSU':
				daText = "sei la que disgrama e isso tambem";
			case 'Efeito Splash na nota':
				daText = "yuhu as setas fazem kabum (no bom sentido)";
			case 'Luzes Piscantes':
				daText = "Deixe desmarcado caso tenha problemas com epilepsia";
			case 'Cenarios Visiveis':
				daText = "Tira o cenário do game e deixa o jogo mais leve \n Só que mais feio \n tem um pequeno risco de deslocar os personagens";
			case 'Pular Cutscenes':
				daText = "Auto-Explicativo eu acho";	
			case 'Pular dialogos':
				daText = "Acho que nao precisa explicar né?";
			case 'Efeitos de camera':
				daText = "Se desmacardo, a camera nao vai ter mais aqueles zooms muito do locos";
			case 'Remover GF':
				daText = "Auto-Explicativo tambem eu acho";
			case 'Ocultar HUD':
				daText = "Se marcado, tua tela vai ficar limpinha (literalmente ^^)";
			case 'Ocultar tempo de musica':
				daText = "Se desmarcado, o reloginho vai sumir, F.";
		}
		descText.text = daText;

		var bullShit:Int = 0;

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
				}

				for (j in 0...checkboxArray.length) {
					var tracker:FlxSprite = checkboxArray[j].sprTracker;
					if(tracker == item) {
						checkboxArray[j].alpha = item.alpha;
						break;
					}
				}
			}
		}
		for (i in 0...grpTexts.members.length) {
			var text:AttachedText = grpTexts.members[i];
			if(text != null) {
				text.alpha = 0.6;
				if(textNumber[i] == curSelected) {
					text.alpha = 1;
				}
			}
		}

		if(options[curSelected] == 'Anti-Aliasing') {
			if(showCharacter == null) {
				showCharacter = new Character(840, 170, 'bf', true);
				showCharacter.setGraphicSize(Std.int(showCharacter.width * 0.8));
				showCharacter.updateHitbox();
				showCharacter.dance();
				characterLayer.add(showCharacter);
			}
		} else if(showCharacter != null) {
			characterLayer.clear();
			showCharacter = null;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadValues() {
		for (i in 0...checkboxArray.length) {
			var checkbox:CheckboxThingie = checkboxArray[i];
			if(checkbox != null) {
				var daValue:Bool = false;
				switch(options[checkboxNumber[i]]) {
					case 'FPS Visivel':
						daValue = ClientPrefs.showFPS;
					case 'Baixa Qualidade':
						daValue = ClientPrefs.lowQuality;
					case 'Anti-Aliasing':
						daValue = ClientPrefs.globalAntialiasing;
					case 'Efeito Splash na nota':
						daValue = ClientPrefs.noteSplashes;
					case 'Luzes Piscantes':
						daValue = ClientPrefs.flashing;
					case 'Cenarios Visiveis':
						daValue = ClientPrefs.cenoptim;
					case 'Pular Cutscenes':
						daValue = ClientPrefs.dacut;
					case 'Pular dialogos':
						daValue = ClientPrefs.dadia;
					case 'Remover GF':
						daValue = ClientPrefs.dagf;
					case 'Downscroll':
						daValue = ClientPrefs.downScroll;
					case 'Middlescroll':
						daValue = ClientPrefs.middleScroll;
					case 'Ghost Tapping':
						daValue = ClientPrefs.ghostTapping;
					case 'Swearing':
						daValue = ClientPrefs.cursing;
					case 'Som de OSU':
						daValue = ClientPrefs.violence;
					case 'Efeitos de camera':
						daValue = ClientPrefs.camZooms;
					case 'Ocultar HUD':
						daValue = ClientPrefs.hideHud;
					case 'Salvar imagens em cache':
						daValue = ClientPrefs.imagesPersist;
					case 'Ocultar tempo de musica':
						daValue = ClientPrefs.hideTime;
				}
				checkbox.daValue = daValue;
			}
		}
		for (i in 0...grpTexts.members.length) {
			var text:AttachedText = grpTexts.members[i];
			if(text != null) {
				var daText:String = '';
				switch(options[textNumber[i]]) {
					case 'FPS':
						daText = '' + ClientPrefs.framerate;
					case 'Delay na nota':
						daText = ClientPrefs.noteOffset + 'ms';
				}
				var lastTracker:FlxSprite = text.sprTracker;
				text.sprTracker = null;
				text.changeText(daText);
				text.sprTracker = lastTracker;
			}
		}
	}

	private function unselectableCheck(num:Int):Bool {
		for (i in 0...unselectableOptions.length) {
			if(options[num] == unselectableOptions[i]) {
				return true;
			}
		}
		return options[num] == '';
	}
}