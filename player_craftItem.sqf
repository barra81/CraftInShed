
private ["_tradeComplete","_onLadder","_canDo","_selectedRecipeOutput","_proceed","_itemIn","_countIn","_missing","_missingQty","_qty","_itemOut","_countOut","_started","_finished","_animState","_isMedic","_removed","_tobe_removed_total","_textCreate","_textMissing","_selectedRecipeInput","_selectedRecipeInputStrict","_num_removed","_removed_total","_temp_removed_array","_abort","_waterLevel","_waterLevel_lowest","_reason","_isNear","_missingTools","_hastoolweapon","_selectedRecipeTools","_distance","_crafting","_needNear","_item","_baseClass","_num_removed_weapons","_outputWeapons","_inputWeapons","_randomOutput","_craft_doLoop","_selectedWeapon","_selectedMag","_sfx"];

if(DZE_ActionInProgress) exitWith { cutText [(localize "str_epoch_player_63") , "PLAIN DOWN"]; };
DZE_ActionInProgress = true;

// This is used to find correct recipe based what itemaction was click allows multiple recipes per item.
_crafting = _this select 0;

// This tells the script what type of item we are clicking on
_baseClass = _this select 1;

_item =  _this select 2;

_abort = false;
_distance = 3;
_reason = "";
_waterLevel = 0;
_outputWeapons = [];
_selectedRecipeOutput = [];
_onLadder =	(getNumber (configFile >> "CfgMovesMaleSdr" >> "States" >> (animationState player) >> "onLadder")) == 1;
_canDo = (!r_drag_sqf && !r_player_unconscious && !_onLadder);

// Need Near Requirements
_needNear = getArray (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "neednearby");
if("fire" in _needNear) then {
	_isNear = {inflamed _x} count (getPosATL player nearObjects _distance);
	if(_isNear == 0) then {
		_abort = true;
		_reason = "fire";
	};
};
if("workshop" in _needNear) then {
	_isNear = count (nearestObjects [player, ["Wooden_shed_DZ","WoodShack_DZ","WorkBench_DZ"], _distance]);
	if(_isNear == 0) then {
		_abort = true;
		_reason = "workshop";
	};
};
if(_abort) exitWith {
	cutText [format[(localize "str_epoch_player_149"),_reason,_distance], "PLAIN DOWN"];
	DZE_ActionInProgress = false;
};

/////////////////////////////// Craft in Shed allowed Sheds array
_PossShedBuild = typeOf cursorTarget in ["Wooden_shed_DZ","WoodShack_DZ","StorageShed_DZ","GunRack_DZ","VaultStorage"];
_regular = true;

if (_canDo) then {


	_selectedRecipeTools = getArray (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "requiretools");
	_selectedRecipeOutput = getArray (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "output");
	_selectedRecipeInput = getArray (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "input");
	_selectedRecipeInputStrict = if ((isNumber (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "inputstrict")) && (getNumber (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "inputstrict") > 0)) then {true} else {false};
	_outputWeapons = getArray (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "outputweapons");
	_inputWeapons = getArray (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "inputweapons");

	_sfx = getText(configFile >> _baseClass >> _item >> "sfx");


if (_canDo && !_PossShedBuild) then {

	
	if(_sfx == "") then {
		_sfx = "repair";
	};

	_randomOutput = 0;
	if(isNumber (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "randomOutput")) then {
		_randomOutput = getNumber(configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "randomOutput");
	};

	_craft_doLoop = true;
	_tradeComplete = 0;

	while {_craft_doLoop} do {

		_temp_removed_array = [];

		_missing = "";
		_missingTools = false;
		{
			_hastoolweapon = _x in weapons player;
			if(!_hastoolweapon) exitWith { _craft_doLoop = false; _missingTools = true; _missing = _x; };
		} forEach _selectedRecipeTools;

		if(!_missingTools) then {


			// Dry run to see if all parts are available.
			_proceed = true;
			if (count _selectedRecipeInput > 0) then {
				{
					_itemIn = _x select 0;
					_countIn = _x select 1;

					_qty = { (_x == _itemIn) || (!_selectedRecipeInputStrict && configName(inheritsFrom(configFile >> "cfgMagazines" >> _x)) == _itemIn) } count magazines player;

					if(_qty < _countIn) exitWith { _missing = _itemIn; _missingQty = (_countIn - _qty); _proceed = false; };

				} forEach _selectedRecipeInput;
			};

			// If all parts proceed
			if (_proceed) then {

				cutText [(localize "str_epoch_player_62"), "PLAIN DOWN"];
		
				[1,1] call dayz_HungerThirst;
				player playActionNow "Medic";

				[player,_sfx,0,false] call dayz_zombieSpeak;
				[player,50,true,(getPosATL player)] spawn player_alertZombies;

				r_interrupt = false;
				_animState = animationState player;
				r_doLoop = true;
				_started = false;
				_finished = false;

				while {r_doLoop} do {
					_animState = animationState player;
					_isMedic = ["medic",_animState] call fnc_inString;
					if (_isMedic) then {
						_started = true;
					};
					if (_started && !_isMedic) then {
						r_doLoop = false;
						_finished = true;
					};
					if (r_interrupt) then {
						r_doLoop = false;
					};
					sleep 0.1;
				};
				r_doLoop = false;

				if (_finished) then {

					_removed_total = 0; // count total of removed items
					_tobe_removed_total = 0; // count total of all to be removed items
					_waterLevel_lowest = 0; // find the lowest _waterLevel
					// Take items
					{
						_removed = 0;
						_itemIn = _x select 0;
						_countIn = _x select 1;

						_tobe_removed_total = _tobe_removed_total + _countIn;

						// Preselect the item
						{
							_configParent = configName(inheritsFrom(configFile >> "cfgMagazines" >> _x));
							if ((_x == _itemIn) || (!_selectedRecipeInputStrict && _configParent == _itemIn)) then {
								// Get lowest waterlevel
								if ((_x == "ItemWaterbottle") ||( _configParent == "ItemWaterbottle")) then {
									_waterLevel = floor((getNumber(configFile >> "CfgMagazines" >> _x >> "wateroz")) - 1);
									if (_waterLevel_lowest == 0 || _waterLevel < _waterLevel_lowest) then {
										_waterLevel_lowest = _waterLevel;
									};
								};
							};
						} forEach magazines player;

						{
							_configParent = configName(inheritsFrom(configFile >> "cfgMagazines" >> _x));
							if( (_removed < _countIn) && ((_x == _itemIn) || (!_selectedRecipeInputStrict && _configParent == _itemIn))) then {
								if ((_waterLevel_lowest == 0) || ((_waterLevel_lowest > 0) && (getNumber(configFile >> "CfgMagazines" >> _x >> "wateroz") == _waterLevel_lowest))) then {
									_num_removed = ([player,_x] call BIS_fnc_invRemove);
								}
								else {
									_num_removed = 0;
								};
								_removed = _removed + _num_removed;
								_removed_total = _removed_total + _num_removed;
								if(_num_removed >= 1) then {

									if (_x == "ItemWaterbottle" || _configParent == "ItemWaterbottle") then {
										_waterLevel = floor((getNumber(configFile >> "CfgMagazines" >> _x >> "wateroz")) - 1);
									};
									_temp_removed_array set [count _temp_removed_array,_x];
								};
							};
						} forEach magazines player;

					} forEach _selectedRecipeInput;

					// Only proceed if all parts were removed successfully
					if(_removed_total == _tobe_removed_total) then {
						_num_removed_weapons = 0;
						{
							_num_removed_weapons = _num_removed_weapons + ([player,_x] call BIS_fnc_invRemove);
						} forEach _inputWeapons;
						if (_num_removed_weapons == (count _inputWeapons)) then {
							if(_randomOutput == 1) then {
								if (!isNil "_outputWeapons" && count _outputWeapons > 0) then {
									_selectedWeapon = _outputWeapons call BIS_fnc_selectRandom;
									_outputWeapons = [_selectedWeapon];
								};
								if (!isNil "_selectedRecipeOutput" && count _selectedRecipeOutput > 0) then {
									_selectedMag = _selectedRecipeOutput call BIS_fnc_selectRandom;
									_selectedRecipeOutput = [_selectedMag];
								};
								// exit loop
								_craft_doLoop = false;
							};
							{
								player addWeapon _x;
							} forEach _outputWeapons;
							{

								_itemOut = _x select 0;
								_countOut = _x select 1;

								if (_itemOut == "ItemWaterbottleUnfilled") then {

									if (_waterLevel > 0) then {
										_itemOut = format["ItemWaterbottle%1oz",_waterLevel];
									};

								};


								for "_x" from 1 to _countOut do {
									player addMagazine _itemOut;
								};

								_textCreate = getText(configFile >> "CfgMagazines" >> _itemOut >> "displayName");

								// Add crafted item
								cutText [format[(localize "str_epoch_player_150"),_textCreate,_countOut], "PLAIN DOWN"];
								// sleep here
								sleep 1;

							} forEach _selectedRecipeOutput;

							_tradeComplete = _tradeComplete+1;
						};

					} else {
						// Refund parts since we failed
						{player addMagazine _x; } forEach _temp_removed_array;

						cutText [format[(localize "str_epoch_player_151"),_removed_total,_tobe_removed_total], "PLAIN DOWN"];
					};

				} else {
					r_interrupt = false;
					if (vehicle player == player) then {
						[objNull, player, rSwitchMove,""] call RE;
						player playActionNow "stop";
					};
					cutText [(localize "str_epoch_player_64"), "PLAIN DOWN"];
					_craft_doLoop = false;
				};

			} else {
				_textMissing = getText(configFile >> "CfgMagazines" >> _missing >> "displayName");
				cutText [format[(localize "str_epoch_player_152"),_missingQty, _textMissing,_tradeComplete], "PLAIN DOWN"];
				_craft_doLoop = false;
			};
		} else {
			_textMissing = getText(configFile >> "CfgWeapons" >> _missing >> "displayName");
			cutText [format[(localize "STR_EPOCH_PLAYER_137"),_textMissing], "PLAIN DOWN"];
			_craft_doLoop = false;
		};
	};
	
	
///////////////////////////////////////////////////////////// Shed Crafting Start///////////////////////////////////////////////////////////////	
	
	} else {
	
	_ShedBuild = cursorTarget;
    _typeOfShed = typeOf _ShedBuild;

	cutText [format["\n\n You are crafting now within %1 ! ", _typeOfShed], "PLAIN DOWN"];

	
	if(_sfx == "") then {
		_sfx = "repair";
	};

	_randomOutput = 0;
	if(isNumber (configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "randomOutput")) then {
		_randomOutput = getNumber(configFile >> _baseClass >> _item >> "ItemActions" >> _crafting >> "randomOutput");
	};

	
	_outDone = "";
	_missing = "";
	_craft_doLoop = true;
	_tradeComplete = 0;

	while {_craft_doLoop} do {

		_temp_removed_array = [];

		

		_missingTools = false;
		{
			_hastoolweapon = _x in weapons player;

			if(!_hastoolweapon) exitWith { _craft_doLoop = false; _missingTools = true; _missing = _x; };
		} forEach _selectedRecipeTools;

		
		if(!_missingTools) then {


			// Dry run to see if all parts are available.
			_proceed = true;
		
			if (count _selectedRecipeInput > 0) then {
				{
					_itemIn = _x select 0;
					_countIn = _x select 1;
					
					
					_shedListActual =	getMagazineCargo _ShedBuild;
					_countActual = _shedListActual select 1;
					_cargoActual = _shedListActual select 0;
					_actualList = [];                          
					{
                     _ii = _cargoActual find _x;
                     for "_i" from 1 to (_countActual select _ii) do {                     //// array format now ["Stanag","Stanag","Granade"]
	                 _actualList set [(count _actualList),_x];
                    };
                    } forEach _cargoActual;					
					
                      _qty = { (_x == _itemIn) || (!_selectedRecipeInputStrict && configName(inheritsFrom(configFile >> "cfgMagazines" >> _x)) == _itemIn) } count _actualList; 
					if(_qty < _countIn) exitWith { _missing = _itemIn; _missingQty = (_countIn - _qty); _proceed = false; };

				} forEach _selectedRecipeInput;
			
			
			
			
			
////////////Check for denied Items to build						

_notPossBuild = ["ItemBriefcase_Base","ItemBriefcase10oz","ItemBriefcase20oz","ItemBriefcase30oz","ItemBriefcase40oz","ItemBriefcase50oz","ItemBriefcase60oz","ItemBriefcase70oz","ItemBriefcase80oz","ItemBriefcase90oz","ItemBriefcase100oz","ItemBriefcaseS10oz","ItemBriefcaseS20oz","ItemBriefcaseS30oz","ItemBriefcaseS40oz","ItemBriefcaseS50oz","ItemBriefcaseS60oz","ItemBriefcaseS70oz","ItemBriefcaseS80oz","ItemBriefcaseS90oz","ItemBriefcaseS100oz"]; //denied item Array
			
		{			
   
		    for "_i" from 0 to count _selectedRecipeInput - 1 do {
	        if (_x in (_selectedRecipeInput select _i)) exitWith {                       //if Item in _notPossBuild and in _selectedRecipeInput then cancel
						  	

						    _proceed = false;
							_regular = false;
	                        cutText [format["\n\n %1 can´t be used within a Shed! ", _x], "PLAIN DOWN"];
							sleep 3;
				            };			       
		    };
	    } forEach _notPossBuild;
		
	  			
				if (count _outputWeapons > 0) exitWith {
                        
					{
							
					_proceed = false;
					_regular = false;
                    cutText [format["\n\n %1 can´t be build within a Shed! ", _x], "PLAIN DOWN"];
					sleep 3;
				    } forEach _outputWeapons;
					
				  };				  
		    };
	

	
			// If all parts proceed
			if (_proceed) then {
				

				[1,1] call dayz_HungerThirst;
				player playActionNow "Medic";

				[player,_sfx,0,false] call dayz_zombieSpeak;
				[player,50,true,(getPosATL player)] spawn player_alertZombies;

				r_interrupt = false;
				_animState = animationState player;
				r_doLoop = true;
				_started = false;
				_finished = false;

				while {r_doLoop} do {
								
					_animState = animationState player;
					_isMedic = ["medic",_animState] call fnc_inString;
					if (_isMedic) then {
						_started = true;
					};
					if (_started && !_isMedic) then {
						r_doLoop = false;
						_finished = true;
					};
					if (r_interrupt) then {
						r_doLoop = false;
					};
					sleep 0.1;
				};
				r_doLoop = false;
		
				
				
				
				if (_finished) then {
				
				
	////// final check if needed Items still in shed			
				_finalCheck = true;
		        _spaceLeft = true;
                _recipeOutCount = 0;
				
               if (count _selectedRecipeInput > 0) then {
				{
					_itemIn = _x select 0;
					_countIn = _x select 1;
					 
					
					_shedListActual =	getMagazineCargo _ShedBuild;
					_countActual = _shedListActual select 1;
					_cargoActual = _shedListActual select 0;
					_actualList = [];                          
					{
                     _ii = _cargoActual find _x;
                     for "_i" from 1 to (_countActual select _ii) do {                     //// array format now = ["Stanag","Stanag","Granade"]
	                 _actualList set [(count _actualList),_x];
                    };
                    } forEach _cargoActual;					
					
                      _qty = { (_x == _itemIn) || (!_selectedRecipeInputStrict && configName(inheritsFrom(configFile >> "cfgMagazines" >> _x)) == _itemIn) } count _actualList; 
					 

					if(_qty < _countIn) then { 
					_missing = _itemIn; 
					_missingQty = (_countIn - _qty);
					_finalCheck = false;
					};
						
				} forEach _selectedRecipeInput;
				
								
				////////check if enough room left in shed to craft
				
				 _maxMagazines =	getNumber (configFile >> "CfgVehicles" >> _typeOfShed >> "transportMaxMagazines");
                 _magazineCount_raw = getMagazineCargo _ShedBuild;               // format is [["Stanag","Granade"],[2,1]]
				 

                 _magazineCount = (_magazineCount_raw select 1) call vehicle_gear_count;
                 _magazineLeft = _maxMagazines - _magazineCount;
                 _totalRecipeOut = count _selectedRecipeOutput ;
				 _totalRecipeIn = count _selectedRecipeInput;
				 

				{
				_itemOut = _x select 0;
				_countOut = _x select 1;
				for "_x" from 1 to _totalRecipeOut do {
			
				_recipeOutCount = _recipeOutCount + _countOut;
								
				};
                } forEach _selectedRecipeOutput;
				
				_recipeInCount = 0;
				{
				_itemIn = _x select 0;
				_countIn = _x select 1;
				for "_x" from 1 to _totalRecipeIn do {
			
				_recipeInCount = _recipeInCount + _countIn;
								
				};
                } forEach _selectedRecipeInput;
				
				_totalRecipeOutCount = _recipeOutCount - _recipeInCount + 1;
				
					
				// ["conGreen",format ["_recipeOutCount = %1  | _totalRecipeOutCount = %2", _recipeOutCount, _totalRecipeOutCount]] call diagLog;	
				 
                if ( _magazineLeft < _totalRecipeOutCount) then {
				
				_finalCheck = false;
				_spaceLeft = false;				
				  };
				  
			 
				};
				
		
				
     if (_finalCheck) then {


	
				if (!isNil "_selectedRecipeOutput" && count _selectedRecipeOutput > 0) then {
		        _selectedMag = _selectedRecipeOutput call BIS_fnc_selectRandom;
				_selectedRecipeOutput = [_selectedMag];
								};
								
																
								
								
					
					_needed = _selectedRecipeInput;	
					_neededCount = count _needed;
					
		       
	          {                                                      //forEach _selectedRecipeOutput START
								_itemOut = _x select 0;
								_countOut = _x select 1;
								_outDone = _itemOut;			       
							    							
								for "_x" from 1 to _countOut do {
									_ShedBuild addMagazineCargoGlobal [_itemOut,1];
								};
							
						
								
					_shedList =	getMagazineCargo _ShedBuild; // shedlist format is [["Stanag","Granade"],[2,1]]
					_countOld = _shedList select 1;
					_cargoOld = _shedList select 0;
					
                    _countNeededStr = (_needed select 0) select 1; 
					_cargoNeededStr = (_needed select 0) select 0;
				
                    _countNeededStr1 = "";
				    _cargoNeededStr1 = "";
					if (_neededCount == 2) then {
				    _countNeededStr1 = (_needed select 1) select 1;
					_cargoNeededStr1 = (_needed select 1) select 0;
				    };
				 				
					_countNeededStr2 = ""; 
					_cargoNeededStr2 = "";
				    if (_neededCount == 3) then {
					_countNeededStr2 = (_needed select 2) select 1; 
					_cargoNeededStr2 = (_needed select 2) select 0;
					};
					_countNeededStr3 = ""; 
					_cargoNeededStr3 = "";
                    if (_neededCount == 4) then {
					_countNeededStr3 = (_needed select 3) select 1; 
					_cargoNeededStr3 = (_needed select 3) select 0;
					};
					
					
				_lastIndexOld = -1;
				_lastIndexOld1 = -1;
				_lastIndexOld2 = -1;
				_lastIndexOld3 = -1;
	  			{			
                  if (_x == _cargoNeededStr) then {
                  _lastIndexOld = _forEachIndex;             // returns position (index pos) of recipeneeded items in the shedarray
                   };  

			   	  if (_neededCount == 2) then {
				  if (_x == _cargoNeededStr1) then {
                  _lastIndexOld1 = _forEachIndex;
                   };
                   };
				   
	              if (_neededCount == 2) then {		   
				  if (_x == _cargoNeededStr2) then {
                  _lastIndexOld2 = _forEachIndex;
                   };
				   };
				   
                  if (_neededCount == 2) then {
				  if (_x == _cargoNeededStr3) then {
                  _lastIndexOld3 = _forEachIndex;
                   }; 
				   };
				   				   
                } forEach _cargoOld;
				
			_resultOld = _countOld select _lastIndexOld;	// total amount of recipe needed items IN shed
			_resultNew = _resultOld - _countNeededStr;   			// amount of recipe needed items - total amount of needed items in shed		
	        
            _resultOld1 = "";
		    _resultNew1 = "";
			if (_neededCount == 2) then {				
			_resultOld1 = _countOld select _lastIndexOld1;
			_resultNew1 = _resultOld1 - _countNeededStr1;
             };
			 
            _resultOld2 = "";
		    _resultNew2 = "";			 
		    if (_neededCount == 3) then {			 
			_resultOld2 = _countOld select _lastIndexOld2;
			_resultNew2 = _resultOld2 - _countNeededStr2;
             }; 
			 
            _resultOld3 = "";
		    _resultNew3 = "";			 
		    if (_neededCount == 4) then {			 
			_resultOld3 = _countOld select _lastIndexOld3;
			_resultNew3 = _resultOld3 - _countNeededStr3;			
			};	


_countOld   set [_lastIndexOld , _resultNew ];		//clear old amount of items and set new amount [pos in array,value]


if (_neededCount == 2) then {
_countOld	set [_lastIndexOld1, _resultNew1];
};

if (_neededCount == 3) then {
_countOld	set [_lastIndexOld2, _resultNew2];
};

if (_neededCount == 4) then {				
_countOld	set [_lastIndexOld3, _resultNew3];		
};

		
_shedListNew = [] + _shedList;     // new parent independent array (only within forEach selectedRecipeOutput)
_shedListNew set [1,_countOld];	   //set pos 1 in array value _countOld


				    _countNew = _shedListNew select 1;
					_cargoNew = _shedListNew select 0;
				    _newList = []; 
{
    _ii = _cargoNew find _x;
    for "_i" from 1 to (_countNew select _ii) do {
	    _newList set [(count _newList ),_x];                   //  array format is now ["Stanag","Stanag","Granade"]
    };
} forEach _cargoNew;	

			 
	          clearMagazineCargoGlobal _ShedBuild;
			  { _ShedBuild addMagazineCargoGlobal [_x,1]; } forEach _newList;  
			 
	
	} forEach _selectedRecipeOutput;
							
			_tradeComplete = _tradeComplete+1;
			
		    _totalItemsOut = _tradeComplete * _recipeOutCount;										
			_textDone = getText(configFile >> "CfgMagazines" >> _outDone >> "displayName");				
			cutText [format["\n\n Crafted %3 %1, total till now: %2 !", _textDone,_totalItemsOut,_recipeOutCount], "PLAIN DOWN"];
					
				} else {   ///finalCheck else
						
					r_interrupt = false;
					if (vehicle player == player) then {
						[objNull, player, rSwitchMove,""] call RE;
						player playActionNow "stop";
					};
					
				if (_spaceLeft) then {
					
				_textMissing = getText(configFile >> "CfgMagazines" >> _missing >> "displayName");
				cutText [format[(localize "str_epoch_player_152"),_missingQty, _textMissing,_tradeComplete], "PLAIN DOWN"];					
						_craft_doLoop = false;
				   
				} else {
				
                cutText [format["\n\n You do not have enough room left, in your %1 ! ", _typeOfShed], "PLAIN DOWN"];
				sleep 2;
				
				_totalItemsOut = _tradeComplete * _recipeOutCount;										
				_textDone = getText(configFile >> "CfgMagazines" >> _outDone >> "displayName");				
				cutText [format["\n\n Crafted %2 %1 !", _textDone,_totalItemsOut], "PLAIN DOWN"];
					
				_craft_doLoop = false;

				};
                  };
			
			
				} else { // if finished else
					r_interrupt = false;
					if (vehicle player == player) then {
						[objNull, player, rSwitchMove,""] call RE;
						player playActionNow "stop";
					};
					
					cutText [(localize "str_epoch_player_64"), "PLAIN DOWN"];
					_craft_doLoop = false;
					
				};

			} else {    			//if proceed else
			
			if (_regular) then {
			
				_textMissing = getText(configFile >> "CfgMagazines" >> _missing >> "displayName");
				cutText [format[(localize "str_epoch_player_152"),_missingQty, _textMissing,_tradeComplete], "PLAIN DOWN"];
				_craft_doLoop = false;
			} else {
			_craft_doLoop = false;		
			};
			};
						
			
		} else {  //if !missingtools else
			_textMissing = getText(configFile >> "CfgWeapons" >> _missing >> "displayName");
			cutText [format[(localize "STR_EPOCH_PLAYER_137"),_textMissing], "PLAIN DOWN"];
			_craft_doLoop = false;
		};
	};		// while craft loop 
	};     // shedbuild true 
		
} else {   // if cando else
	cutText [(localize "str_epoch_player_64"), "PLAIN DOWN"];
};
DZE_ActionInProgress = false;