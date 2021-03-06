﻿/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// Scratch.as
// John Maloney, September 2009
//
// This is the top-level application.

package {
import com.quetwo.Arduino.ArduinoConnector;
import com.quetwo.Arduino.ArduinoConnectorEvent;

import flash.desktop.NativeApplication;
import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.display.DisplayObject;
import flash.display.Graphics;
import flash.display.Shape;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageDisplayState;
import flash.display.StageScaleMode;
import flash.errors.IllegalOperationError;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.InvokeEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.ProgressEvent;
import flash.events.TimerEvent;
import flash.events.UncaughtErrorEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.FileReference;
import flash.net.FileReferenceList;
import flash.net.LocalConnection;
import flash.net.URLRequest;
import flash.net.navigateToURL;
import flash.system.Capabilities;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.utils.ByteArray;
import flash.utils.Timer;
import flash.utils.clearInterval;
import flash.utils.getTimer;
import flash.utils.setInterval;

import blocks.Block;

import extensions.ExtensionManager;

import interpreter.Interpreter;

import primitives.CFunPrims;

import render3d.DisplayObjectContainerIn3D;

import scratch.BlockMenus;
import scratch.PaletteBuilder;
import scratch.ScratchCostume;
import scratch.ScratchObj;
import scratch.ScratchRuntime;
import scratch.ScratchSound;
import scratch.ScratchSprite;
import scratch.ScratchStage;

import translation.Translator;

import ui.BlockPalette;
import ui.CameraDialog;
import ui.LoadProgress;
import ui.media.MediaInfo;
import ui.media.MediaLibrary;
import ui.media.MediaPane;
import ui.parts.ImagesPart;
import ui.parts.LibraryPart;
import ui.parts.ScriptsPart;
import ui.parts.SoundsPart;
import ui.parts.StagePart;
import ui.parts.TabsPart;
import ui.parts.TopBarPart;

import uiwidgets.BlockColorEditor;
import uiwidgets.CursorTool;
import uiwidgets.DialogBox;
import uiwidgets.IconButton;
import uiwidgets.Menu;
import uiwidgets.ScriptsPane;

import util.GestureHandler;
import util.ProjectIO;
import util.Server;
import util.Transition;

import watchers.ListWatcher;

//网络外链_wh

//import primitives.*;//输出testnum用_wh


public class Scratch extends Sprite {
	// Version
	public static const versionString:String = 'v446';//版本号_wh
	public static var app:Scratch; // static reference to the app, used for debugging

	// Display modes
	public var editMode:Boolean; // true when project editor showing, false when only the player is showing//编辑框标志
	public var isOffline:Boolean; // true when running as an offline (i.e. stand-alone) app//离线版本标志
	public var isSmallPlayer:Boolean; // true when displaying as a scaled-down player (e.g. in search results)
	public var stageIsContracted:Boolean; // true when the stage is half size to give more space on small screens
	public var isIn3D:Boolean;
	public var render3D:IRenderIn3D;
	public var isArmCPU:Boolean;
	public var jsEnabled:Boolean = false; // true when the SWF can talk to the webpage//

	// Runtime
	public var runtime:ScratchRuntime;
	public var interp:Interpreter;
	public var extensionManager:ExtensionManager;
	public var server:Server;
	public var gh:GestureHandler;
	public var projectID:String = '';
	public var projectOwner:String = '';
	public var projectIsPrivate:Boolean;
	public var oldWebsiteURL:String = '';
	public var loadInProgress:Boolean;
	public var debugOps:Boolean = false;
	public var debugOpCmd:String = '';

	protected var autostart:Boolean;
	private var viewedObject:ScratchObj;
	private var lastTab:String = 'scripts';
	protected var wasEdited:Boolean; // true if the project was edited and autosaved
	private var _usesUserNameBlock:Boolean = false;
	protected var languageChanged:Boolean; // set when language changed

	// UI Elements
	public var playerBG:Shape;
	public var palette:BlockPalette;
	public var scriptsPane:ScriptsPane;
	public var stagePane:ScratchStage;
	public var mediaLibrary:MediaLibrary;
	public var lp:LoadProgress;
	public var cameraDialog:CameraDialog;

	// UI Parts
	public var libraryPart:LibraryPart;
	protected var topBarPart:TopBarPart;
	protected var stagePart:StagePart;
	private var tabsPart:TabsPart;
	protected var scriptsPart:ScriptsPart;
	public var imagesPart:ImagesPart;
	public var soundsPart:SoundsPart;
	public const tipsBarClosedWidth:int = 17;
	
	public var arduino:ArduinoConnector;//串口类_wh
	public var comTrue:Boolean = false;//COM口是否开启_wh
	public var comIDTrue:String = 'COM0';//当前选中打开的COM口_wh
	public var comDataArray:Array = new Array();//串口接收数据缓存_wh
	public var comDataArrayOld:Array = new Array();//串口接收数据缓存未处理数据_wh
	public var comRevFlag:Boolean = false;//串口数据接收完整性判断标识_wh
	public var comCOMing:Boolean = false;//当前正有外设模块交互通信标志_wh
	
	public var process:NativeProcess = new NativeProcess();//调用本机cmd.exe用_wh
	public var process2:NativeProcess = new NativeProcess();//调用本机cmd.exe用_wh
	public var nativePSInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();//_wh
	public var file0:File;//avrdud操作命令批处理文件cmd.bat（非必须）_wh
	public var cmdBackNum:int = 0;
//	public var waitText:TextField=new TextField();//文本框_wh
//	public var _lableAttribute:TextFormat;
	public var connectCir:Shape = new Shape();//通信标志圆_wh
	public var connectComIDText:TextField = new TextField();
	
	public var delay1sTimer:Timer;//定时器_wh
	
	public var ArduinoFlag:Boolean = false;//是否需要生成Arduino程序_wh
	public var ArduinoLoopFlag:Boolean = false;//是否进入Loop_wh
	public var ArduinoReadFlag:Boolean = false;//当前同一条目下是否为读操作_wh
	public var ArduinoReadStr:Array = new Array;//先存储读的Arduino语句_wh
	public var ArduinoValueFlag:Boolean = false;//是否有变量保持字符类型_wh
	public var ArduinoValueStr:String = new String;//变量字符型_wh
	public var ArduinoMathFlag:Boolean = false;//是否有运算保持字符类型_wh
	public var ArduinoMathStr:Array = new Array;//运算字符型_wh
	public var ArduinoMathNum:Number = 0;//运算嵌入层数_wh
	public var ArduinoFile:File;//_wh
	public var ArduinoFs:FileStream;//_wh
	public var ArduinoFileB:File;//_wh
	public var ArduinoFsB:FileStream;//_wh
	public var ArduinoPinFile:File;//pinmode_wh
	public var ArduinoPinFs:FileStream;//_wh
	public var ArduinoDoFile:File;//_wh
	public var ArduinoDoFs:FileStream;//_wh
	public var ArduinoHeadFile:File;//include和变量定义_wh
	public var ArduinoHeadFs:FileStream;//_wh
	public var ArduinoLoopFile:File;//循环_wh
	public var ArduinoLoopFs:FileStream;//_wh
	public var ArduinoPin:Array = new Array;//pinmode无定义：0；输入：1；输出：2_wh
	public var ArduinoBlock:Array = new Array ;//创趣模块类变量是否定义：无：0；是：1_wh
	public var ArduinoBracketFlag:Number = 0;//是否需要加尾部括号（例如if内部代码块尾部）_wh
	public var ArduinoIEFlag:int = 0;//是否需要加尾部括号（IfElse的if后面）_wh
	public var ArduinoIEFlag2:int = 0;//_wh
	public var ArduinoIEFlagIE:Boolean = false;//_wh
	public var ArduinoIEFlagAll:int = 0;//需要加尾部括号总量（IfElse的if后面）_wh
	public var ArduinoIEElseNum:int = 0;
	public var ArduinoIEElseFlag:int = 0;//是否需要加尾部括号（IfElse的else后面）_wh
	public var ArduinoIEElseFlag2:int = 0;
	//public var ArduinoIEBracketFlag:int = 0;
	
	public var closeOK:Boolean = false;//是否可以关闭软件_wh
	public var closeWait:Boolean = false;//等待文件保存完成情况_wh
	public var ArduinoWarnFlag:Boolean = false;//Arduino过程中是否有警告框弹出_wh
	public var ArduinoRPFlag:Boolean = false;//Arduino生成模块右键选择相关项是否按下_wh
	public var ArduinoRPNum:Number = 0;//Arduino生成模块右键选择相关项编号_wh
	public var openNum:Boolean = false;//_wh
	
	public var ArduinoUs:Boolean = false;//超声波_wh
	public var ArduinoSeg:Boolean = false;//数码管_wh
	public var ArduinoRGB:Boolean = false;//三色灯_wh
	public var ArduinoBuz:Boolean = false;//无源蜂鸣器_wh
	public var ArduinoCap:Boolean = false;//电容值_wh
	public var ArduinoDCM:Boolean = false;//方向电机_wh
	public var ArduinoSer:Boolean = false;//舵机_wh
	public var ArduinoIR:Boolean = false;//红外遥控_wh
	public var ArduinoTem:Boolean = false;//温度_wh
	public var ArduinoAvo:Boolean = false;//避障_wh
	public var ArduinoTra:Boolean = false;//循迹_wh
	public var ArduinoLCD1602:Boolean = false;//LCD1602_xuhy
	
	//public var ArduinoNAN:Boolean = false;//无效数据标志_wh
	
	public var timeDelayAll:Number = 0;//需延时时间_wh
	public var timeStart:Number = 0;//当前时间_wh
	public var tFlag:Boolean = false;//是否需要延时_wh
	
	public var blueFlag:Boolean = false;//是否蓝牙通信模式_wh
	public var readCDFlag:Boolean = false;//通信丢失提示框标志清零_wh
	
	public var CKkey1:Number = 0;//CK板变量值_wh
	public var CKkey2:Number = 0;//CK板变量值_wh
	public var CKsound:Number = 0;//CK板变量值_wh
	public var CKslide:Number = 0;//CK板变量值_wh
	public var CKlight:Number = 0;//CK板变量值_wh

	public var CKjoyx:Number = 0;//CK板变量值_wh
	public var CKjoyy:Number = 0;//CK板变量值_wh
	
	public var UpDialog:DialogBox = new DialogBox();//_wh
	public var ArduinoFirmFlag:Number = 0;//固件下载变量值_wh
	public var UDFlag:Boolean = false;//固件下载变量值_wh
	
	public var DriveFlag:Number = 0;//驱动安装变量值_wh
	public var OS:String = new String;
	
	public var test:Number = 0;//测试量_wh
	public var cfunprime:CFunPrims = new CFunPrims(this,interp);
	
	public var showCOMFlag:Boolean = false;//COM口正在连接_wh
	public var IntervalID:uint = 0x00; 				//查询UART是否工作正常定时器的ID号，可以用于清除定时器。
	
	public var LibraryButtonDown:Boolean = false;
	/*************************************************************************************************/
	public var debugwh:Boolean = false;//是否为debug模式（应用文件路径读取无法在debug模式上通过）_wh
	/*************************************************************************************************/
	
	public function Scratch() {
		//传递应用程序启动参数_wh
		if(debugwh == false)
			NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, onInvokeEvent); 
		
		//监听全局未处理（没有在try…catch里）的异常，并在uncaughtErrorHandler函数中处理_wh
		loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, uncaughtErrorHandler);
		app = this;

		// This one must finish before most other queries can start, so do it separately
		determineJSAccess();//initialize()函数_wh
		
	}
	
	//应用事件处理_wh
	public function onInvokeEvent(invocation:InvokeEvent):void {
		var sb2str:String = invocation.arguments[0];
		sb2str = invocation.currentDirectory.nativePath;
		//若为双击.sb2文件打开，则导入工程_wh
		if(sb2str.indexOf(".sb2") != -1)
		{
			//快捷键打开下一工程时提示先保存_wh
			if(openNum)
				return;
			var reg:RegExp = /\\/g;//斜杠反向用正则表达式_wh
			var strsb:String = sb2str.replace(reg,"/");//注意，必须赋值，因为str本身未改变_wh
			runtime.initProjectFile(strsb);
		}
		//若为双击.sb2文件打开，则导入工程_wh
		if(sb2str.indexOf(".sb") != -1)
		{
			//快捷键打开下一工程时提示先保存_wh
			if(openNum)
				return;
			var reg:RegExp = /\\/g;//斜杠反向用正则表达式_wh
			var strsb:String = sb2str.replace(reg,"/");//注意，必须赋值，因为str本身未改变_wh
			runtime.initProjectFile(strsb);
		}
	} 
	
	public var dllOk:Number = 10;
	protected function initialize():void {
		var file1:File;
		//*******************************************注意：每个版本需要修改（包括相应文件）*****************************************//
		file1= new File(File.userDirectory.resolvePath("YoungMakerASBlock/arduinos/flag_v.txt").nativePath);//在相应目录下寻找或建立dll.txt_wh
		//*******************************************注意：每个版本需要修改（包括相应文件）****************************************//
		var fs:FileStream = new FileStream();
		try
		{
			fs.open(file1,FileMode.READ);
			fs.position = 0;
			var i:int = fs.readByte();
			fs.close();
		}
		catch(Error)
		{
			i = 0;
		}
		if(i == 49)
			dllOk = 14;
		else
		{
			//将dll文件放在系统目录下_wh
			var OS32:Boolean = Capabilities.supports32BitProcesses;//是否支持32位机_wh
			var OS64:Boolean = Capabilities.supports64BitProcesses;//是否为64位机_wh
			OS = Capabilities.os;//操作系统_wh
			var OS32str:String = "C:/Windows/System32/";
			var OS64str:String = "C:/Windows/SysWOW64/";
			var file2:File;
			var file3:File;
			try
			{
				file3= new File(File.applicationDirectory.resolvePath("avrtool/pthreadVC2.dll").nativePath);//_wh
				if(OS64)
					file2= new File(File.applicationDirectory.resolvePath(OS64str+"pthreadVC2.dll").nativePath);//_wh
				else
					file2= new File(File.applicationDirectory.resolvePath(OS32str+"pthreadVC2.dll").nativePath);//_wh
				if(file2.exists)
				{
					dllOk ++;
					file3.copyTo(file2,true);
				}
				else
				{
					file3.copyTo(file2,true);
					dllOk ++;
				}
			}
			catch(Error)
			{
				;
			}
			try
			{
				file3= new File(File.applicationDirectory.resolvePath("avrtool/msvcr100d.dll").nativePath);//_wh
				if(OS64)
					file2= new File(File.applicationDirectory.resolvePath(OS64str+"msvcr100d.dll").nativePath);//_wh
				else
					file2= new File(File.applicationDirectory.resolvePath(OS32str+"msvcr100d.dll").nativePath);//_wh
				if(file2.exists)
				{
					dllOk ++;
					file3.copyTo(file2,true);
				}
				else
				{
					file3.copyTo(file2,true);
					dllOk ++;
				}
			}
			catch(Error)
			{
				;
			}
			try
			{
				file3= new File(File.applicationDirectory.resolvePath("avrtool/msvcr120d.dll").nativePath);//_wh
				if(OS64)
					file2= new File(File.applicationDirectory.resolvePath(OS64str+"msvcr120d.dll").nativePath);//_wh
				else
					file2= new File(File.applicationDirectory.resolvePath(OS32str+"msvcr120d.dll").nativePath);//_wh
				if(file2.exists)
				{
					dllOk ++;
					file3.copyTo(file2,true);
				}
				else
				{
					file3.copyTo(file2,true);
					dllOk ++;
				}
			}
			catch(Error)
			{
				;
			}
			try
			{
				if(OS64)
				{
					file3= new File(File.applicationDirectory.resolvePath("avrtool/win7/msvcr100.dll").nativePath);//_wh
					file2= new File(File.applicationDirectory.resolvePath(OS64str+"msvcr100.dll").nativePath);//_wh
				}
				else
				{
					file3= new File(File.applicationDirectory.resolvePath("avrtool/xp/msvcr100.dll").nativePath);//_wh
					file2= new File(File.applicationDirectory.resolvePath(OS32str+"msvcr100.dll").nativePath);//_wh
				}
				if(file2.exists)
				{
					dllOk ++;
					file3.copyTo(file2,true);
				}
				else
				{
					file3.copyTo(file2,true);
					dllOk ++;
				}
			}
			catch(Error)
			{
				;
			}
			if(dllOk > 10)
			{
				fs.open(file1,FileMode.WRITE);
				fs.position = 0;
				fs.writeUTFBytes("1");
				fs.close();
			}
		}
		
		//Arduino程序生成相关文件新建_wh
		app.ArduinoHeadFile= new File(File.userDirectory.resolvePath("YoungMakerASBlock/arduinos/head.txt").nativePath);
		app.ArduinoHeadFs = new FileStream();
		app.ArduinoPinFile= new File(File.userDirectory.resolvePath("YoungMakerASBlock/arduinos/pin.txt").nativePath);
		app.ArduinoPinFs = new FileStream();
		app.ArduinoDoFile= new File(File.userDirectory.resolvePath("YoungMakerASBlock/arduinos/do.txt").nativePath);
		app.ArduinoDoFs = new FileStream();
		app.ArduinoLoopFile= new File(File.userDirectory.resolvePath("YoungMakerASBlock/arduinos/loop.txt").nativePath);
		app.ArduinoLoopFs = new FileStream();
		app.ArduinoFile= new File(File.userDirectory.resolvePath("YoungMakerASBlock/arduinos/arduinos.ino").nativePath);
		app.ArduinoFs = new FileStream();
		app.ArduinoFileB= new File(File.userDirectory.resolvePath("YoungMakerASBlock/ArduinoBuilder/arduinos.ino").nativePath);
		app.ArduinoFsB = new FileStream();
		
		
		isOffline = loaderInfo.url.indexOf('http:') == -1;//ture为本地_wh
		checkFlashVersion();//Flash版本处理函数？_wh
		initServer();//事件处理服务相关_wh

		stage.align = StageAlign.TOP_LEFT;//swf文件在浏览器、播放器中的对齐方式_wh
		stage.scaleMode = StageScaleMode.NO_SCALE;//缩放属性_wh
		stage.frameRate = 30;//渲染帧率_wh
		stage.stageWidth = 1100;//增加软件窗口初始化设置，_wh
		stage.stageHeight = 640;//增加软件窗口初始化设置，_wh
	
		
		Block.setFonts(10, 9, true, 0);//初始化字体大小_wh；此处改没用，需要在更底层修改_wh 
		Block.MenuHandlerFunction = BlockMenus.BlockMenuHandler;//右键、下拉等处理_wh
		CursorTool.init(this);//光标_wh
		app = this;

		stagePane = new ScratchStage();//舞台_wh
		gh = new GestureHandler(this, (loaderInfo.parameters['inIE'] == 'true'));//鼠标状态处理类_wh
		initInterpreter();//Interpreter() 多线程开启_wh
		initRuntime();//ScratchRuntime() ?_wh
		initExtensionManager();//外设模块添加，提供的源码不知道从哪使能，另外不适用其原先的json方法，但去掉影响CFun模块的显示，原因未理解_wh
		Translator.initializeLanguageList();//语言选择初始化

		playerBG = new Shape(); // create, but don't add
		
		addParts();
		libraryPart.initSprite(0);//初始化对象_wh
		
		server.getSelectedLang(Translator.setLanguageValue);
		

		stage.addEventListener(MouseEvent.MOUSE_DOWN, gh.mouseDown);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, gh.mouseMove);
		stage.addEventListener(MouseEvent.MOUSE_UP, gh.mouseUp);
		stage.addEventListener(MouseEvent.MOUSE_WHEEL, gh.mouseWheel);
		stage.addEventListener('rightClick', gh.rightMouseClick);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, runtime.keyDown);
		stage.addEventListener(KeyboardEvent.KEY_UP, runtime.keyUp);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown); // to handle escape key
		stage.addEventListener(Event.ENTER_FRAME, step);//运行事件处理_wh
		stage.addEventListener(Event.RESIZE, onResize);
		
		stage.nativeWindow.addEventListener(Event.CLOSING,closingHandler);//关闭按钮触发事件_wh

		setEditMode(startInEditMode());

		// install project before calling fixLayout()
		if (editMode) runtime.installNewProject();
		else runtime.installEmptyProject();

		fixLayout();
		//Analyze.collectAssets(0, 119110);
		//Analyze.checkProjects(56086, 64220);
		//Analyze.countMissingAssets();
		
		
		arduino = new ArduinoConnector();//新建COM变量_wh
		
		CFunConCir(0);//通信标志三点_wh
		
		delay1sTimer = new Timer(1000, 75);//每2s一个中断，持续75s_wh 在线约10s，无线61s
		delay1sTimer.addEventListener(TimerEvent.TIMER, onTick); 
		delay1sTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimerComplete);
		
		ArduinoBlock[CFunPrims.ID_ReadAFloat] = new Array();//二维数组新建，Arduino生成过程避免变量反复定义用_wh
		ArduinoBlock[CFunPrims.ID_ReadPFloat] = new Array();//二维数组新建，Arduino生成过程避免变量反复定义用_wh
		ArduinoBlock[CFunPrims.ID_SetSG] = new Array();//二维数组新建，Arduino生成过程避免变量反复定义用_wh
		ArduinoBlock[CFunPrims.ID_SetDM] = new Array();//二维数组新建，Arduino生成过程避免变量反复定义用_wh
		ArduinoBlock[CFunPrims.ID_SetNUM] = new Array();//二维数组新建，Arduino生成过程避免变量反复定义用_wh
		ArduinoBlock[CFunPrims.ID_SetMUS] = new Array();//二维数组新建，Arduino生成过程避免变量反复定义用_wh
	}
	
	//延时tms_wh
	public function CFunDelayms(t:Number):void
	{
		timeStart = getTimer();
		timeDelayAll = t;
		tFlag = true;
		//test = 0;
	}
	
	//通信标志_wh
	public function CFunConCir(b:Number):void
	{
		//通信正常标志_wh
		if(b == 1)
		{
			CFunConCir_Flag = true;
			connectCir.graphics.beginFill(0x80ff00);
			connectCir.graphics.drawCircle(TopBarPart.UartAutoConnectX + 110,15,8);
			connectCir.graphics.drawCircle(TopBarPart.UartAutoConnectX + 130,15,8);
			connectCir.graphics.drawCircle(TopBarPart.UartAutoConnectX + 150,15,8);
			connectCir.graphics.endFill();
			addChild(connectCir);
			
		}
		else
		{
			if(b == 0)
			{
				CFunConCir_Flag = false;
				connectCir.graphics.beginFill(0xff8060);
				connectCir.graphics.drawCircle(TopBarPart.UartAutoConnectX + 110,15,8);
				connectCir.graphics.drawCircle(TopBarPart.UartAutoConnectX + 130,15,8);
				connectCir.graphics.drawCircle(TopBarPart.UartAutoConnectX + 150,15,8);
				connectCir.graphics.endFill();
				addChild(connectCir);
			}
			else
			{
//				connectCir.graphics.beginFill(0xE0E000);
//				connectCir.graphics.drawCircle(350,15,8);
//				connectCir.graphics.drawCircle(370,15,8);
//				connectCir.graphics.drawCircle(390,15,8);
//				connectCir.graphics.endFill();
//				addChild(connectCir);
			}
		}
	}
	
	//关闭按钮触发事件处理函数_wh
	protected function closingHandler(e:Event):void
	{
		var winClosingEvent:Event; 
		winClosingEvent = new Event(Event.CLOSING,false,true); 
		NativeApplication.nativeApplication.dispatchEvent(winClosingEvent); 
		e.preventDefault();//终止关闭进程，需要先提示保存工程_wh
		
		DialogBox.saveconfirm(Translator.map("Save project?"), app.stage, savePro, nosavePro);//软件界面中部显示提示框_wh
	}
	
	//_wh
	protected function savePro():void
	{
		exportProjectToFile();
		closeWait = true;
	}
	
	//_wh
	protected function nosavePro():void
	{
		closeOK = true;
	}
	
	protected function initTopBarPart():void {
		topBarPart = new TopBarPart(this);
	}

	protected function initInterpreter():void {
		interp = new Interpreter(this);
	}

	protected function initRuntime():void {
		runtime = new ScratchRuntime(this, interp);
	}

	protected function initExtensionManager():void {
		extensionManager = new ExtensionManager(this);
	}

	protected function initServer():void {
		server = new Server();
	}

	protected function setupExternalInterface(oldWebsitePlayer:Boolean):void {
		if (!jsEnabled) return;

		addExternalCallback('ASloadExtension', extensionManager.loadRawExtension);
		addExternalCallback('ASextensionCallDone', extensionManager.callCompleted);
		addExternalCallback('ASextensionReporterDone', extensionManager.reporterCompleted);
	}

	//模块右键帮助_wh
	public function showTip(tipName:String):void {
		switch(tipName)
		{
			case "readtrack:":DialogBox.blockhelp("read track sensor",Translator.map("Pin ") + "A1/A2", null, app.stage);break;
			case "readavoid:":DialogBox.blockhelp("read avoid obstacle sensor",Translator.map("Pin ") + "12/13", null, app.stage);break;
			case "readpower:":DialogBox.blockhelp("read power sensor",Translator.map("Pin ") + "A5", null, app.stage);break;
			case "setforward:":DialogBox.blockhelp("set forward speed as %n",Translator.map("Pin ") + "5/7/6/8", null, app.stage);break;
			case "setback:":DialogBox.blockhelp("set back speed as %n",Translator.map("Pin ") + "5/7/6/8", null, app.stage);break;
			case "setleft:":DialogBox.blockhelp("set left speed as %n",Translator.map("Pin ") + "5/7/6/8", null, app.stage);break;
			case "setright:":DialogBox.blockhelp("set right speed as %n",Translator.map("Pin ") + "5/7/6/8", null, app.stage);break;
			case "setarm:":DialogBox.blockhelp("set arm %m.arm angle as %n",Translator.map("Pin ") + "9/10", null, app.stage);break;
			case "readcksound":DialogBox.blockhelp("sound",Translator.map("Pin ") + "A3\n" + Translator.map("Range ") + "0-100", null, app.stage);break;
			case "readckslide":DialogBox.blockhelp("slide",Translator.map("Pin ") + "A4\n" + Translator.map("Range ") + "0-100", null, app.stage);break;
			case "readcklight":DialogBox.blockhelp("light",Translator.map("Pin ") + "A5\n" + Translator.map("Range ") + "0-100", null, app.stage);break;
			case "readckUltrasonicSensor":DialogBox.blockhelp("UltrasonicSensor",Translator.map("Pin ") + "A2 A3\n" + Translator.map("Range ") + "0-100", null, app.stage);break;
			case "readckkey1":DialogBox.blockhelp("red key",Translator.map("Pin ") + "2", null, app.stage);break;
			case "readckkey2":DialogBox.blockhelp("green key",Translator.map("Pin ") + "3", null, app.stage);break;
			case "readckjoyx":DialogBox.blockhelp("joystick X",Translator.map("Pin ") + "A1\n" + Translator.map("Range ") + "-100-100", null, app.stage);break;
			case "readckjoyy":DialogBox.blockhelp("joystick Y",Translator.map("Pin ") + "A2\n" + Translator.map("Range ") + "-100-100", null, app.stage);break;
			case "setckled:":DialogBox.blockhelp("set LED as %m.onoff",Translator.map("Pin ") + "13", null, app.stage);break;
			case "setrgb:":DialogBox.blockhelp("set colors LED as R %n G %n B %n",Translator.map("Pin ") + "9/10/11", null, app.stage);break;
			case "setlcd1602string:":DialogBox.blockhelp("set lcd1602 as %s",Translator.map("Pin ") + "9/10/11", null, app.stage);break;
			default:break;
		}
	}
	public function closeTips():void {}
	public function reopenTips():void {}
	public function tipsWidth():int { return 0; }

	protected function startInEditMode():Boolean {
		return isOffline;
	}

	public function getMediaLibrary(type:String, whenDone:Function):MediaLibrary {
		return new MediaLibrary(this, type, whenDone);
	}

	public function getMediaPane(app:Scratch, type:String):MediaPane {
		return new MediaPane(app, type);
	}

	public function getScratchStage():ScratchStage {
		return new ScratchStage();
	}

	public function getPaletteBuilder():PaletteBuilder {
		return new PaletteBuilder(this);
	}

	private function uncaughtErrorHandler(event:UncaughtErrorEvent):void
	{
		if (event.error is Error)
		{
			var error:Error = event.error as Error;
			logException(error);
		}
		else if (event.error is ErrorEvent)
		{
			var errorEvent:ErrorEvent = event.error as ErrorEvent;
			logMessage(errorEvent.toString());
		}
	}

	public function log(s:String):void {
		trace(s);
	}

	public function logException(e:Error):void {}
	public function logMessage(msg:String, extra_data:Object=null):void {}
	public function loadProjectFailed():void {}

	protected function checkFlashVersion():void {
		/*SCRATCH::allow3d _wh*/ {
			if (Capabilities.playerType != "Desktop" || Capabilities.version.indexOf('IOS') === 0) {
				var versionString:String = Capabilities.version.substr(Capabilities.version.indexOf(' ') + 1);
				var versionParts:Array = versionString.split(',');
				var majorVersion:int = parseInt(versionParts[0]);
				var minorVersion:int = parseInt(versionParts[1]);
				if ((majorVersion > 11 || (majorVersion == 11 && minorVersion >= 7)) && !isArmCPU && Capabilities.cpuArchitecture == 'x86') {
					render3D = (new DisplayObjectContainerIn3D() as IRenderIn3D);
					render3D.setStatusCallback(handleRenderCallback);
					return;
				}
			}
		}

		render3D = null;
	}

	/*SCRATCH::allow3d _wh*/
	protected function handleRenderCallback(enabled:Boolean):void {
		if(!enabled) {
			go2D();
			render3D = null;
		}
		else {
			for(var i:int=0; i<stagePane.numChildren; ++i) {
				var spr:ScratchSprite = (stagePane.getChildAt(i) as ScratchSprite);
				if(spr) {
					spr.clearCachedBitmap();
					spr.updateCostume();
					spr.applyFilters();
				}
			}
			stagePane.clearCachedBitmap();
			stagePane.updateCostume();
			stagePane.applyFilters();
		}
	}

	public function clearCachedBitmaps():void {
		for(var i:int=0; i<stagePane.numChildren; ++i) {
			var spr:ScratchSprite = (stagePane.getChildAt(i) as ScratchSprite);
			if(spr) spr.clearCachedBitmap();
		}
		stagePane.clearCachedBitmap();

		// unsupported technique that seems to force garbage collection
		try {
			new LocalConnection().connect('foo');
			new LocalConnection().connect('foo');
		} catch (e:Error) {}
	}

	/*SCRATCH::allow3d _wh*/
	public function go3D():void {
		if(!render3D || isIn3D) return;

		var i:int = stagePart.getChildIndex(stagePane);
		stagePart.removeChild(stagePane);
		render3D.setStage(stagePane, stagePane.penLayer);
		stagePart.addChildAt(stagePane, i);
		isIn3D = true;
	}

	/*SCRATCH::allow3d _wh*/
	public function go2D():void {
		if(!render3D || !isIn3D) return;

		var i:int = stagePart.getChildIndex(stagePane);
		stagePart.removeChild(stagePane);
		render3D.setStage(null, null);
		stagePart.addChildAt(stagePane, i);
		isIn3D = false;
		for(i=0; i<stagePane.numChildren; ++i) {
			var spr:ScratchSprite = (stagePane.getChildAt(i) as ScratchSprite);
			if(spr) {
				spr.clearCachedBitmap();
				spr.updateCostume();
				spr.applyFilters();
			}
		}
		stagePane.clearCachedBitmap();
		stagePane.updateCostume();
		stagePane.applyFilters();
	}

	protected function determineJSAccess():void {
		// After checking for JS access, call initialize().
		initialize();
	}

	private var debugRect:Shape;
	public function showDebugRect(r:Rectangle):void {
		// Used during debugging...
		var p:Point = stagePane.localToGlobal(new Point(0, 0));
		if (!debugRect) debugRect = new Shape();
		var g:Graphics = debugRect.graphics;
		g.clear();
		if (r) {
			g.lineStyle(2, 0xFFFF00);
			g.drawRect(p.x + r.x, p.y + r.y, r.width, r.height);
			addChild(debugRect);
		}
	}

	public function strings():Array {
		return [
			'a copy of the project file on your computer.',
			'Project not saved!', 'Save now', 'Not saved; project did not load.',
			'Save project?', 'Don\'t save',
			'Save now', 'Saved',
			'Revert', 'Undo Revert', 'Reverting...',
			'Throw away all changes since opening this project?',
		];
	}

	public function viewedObj():ScratchObj { return viewedObject; }
	public function stageObj():ScratchStage { return stagePane; }
	public function projectName():String { return stagePart.projectName(); }
	public function highlightSprites(sprites:Array):void { libraryPart.highlight(sprites); }
	public function refreshImageTab(fromEditor:Boolean):void { imagesPart.refresh(fromEditor); }
	public function refreshSoundTab():void { soundsPart.refresh(); }
	public function selectCostume():void { imagesPart.selectCostume(); }
	public function selectSound(snd:ScratchSound):void { soundsPart.selectSound(snd); }
	public function clearTool():void { CursorTool.setTool(null); topBarPart.clearToolButtons(); }
	public function tabsRight():int { return tabsPart.x + tabsPart.w; }
	public function enableEditorTools(flag:Boolean):void { imagesPart.editor.enableTools(flag); }

	public function get usesUserNameBlock():Boolean {
		return _usesUserNameBlock;
	}

	public function set usesUserNameBlock(value:Boolean):void {
		_usesUserNameBlock = value;
		stagePart.refresh();
	}

	public function updatePalette(clearCaches:Boolean = true):void {
		// Note: updatePalette() is called after changing variable, list, or procedure
		// definitions, so this is a convenient place to clear the interpreter's caches.
		if (isShowing(scriptsPart)) scriptsPart.updatePalette();
		if (clearCaches) runtime.clearAllCaches();
	}

	public function setProjectName(s:String):void {
		if (s.slice(-3) == '.sb') s = s.slice(0, -3);
		if (s.slice(-4) == '.sb2') s = s.slice(0, -4);
		stagePart.setProjectName(s);
	}

	protected var wasEditing:Boolean;
	public function setPresentationMode(enterPresentation:Boolean):void {
		if (enterPresentation) {
			wasEditing = editMode;
			if (wasEditing) {
				setEditMode(false);
				if(jsEnabled) externalCall('tip_bar_api.hide');
			}
		} else {
			if (wasEditing) {
				setEditMode(true);
				if(jsEnabled) externalCall('tip_bar_api.show');
			}
		}
		if (isOffline) {
			stage.displayState = enterPresentation ? StageDisplayState.FULL_SCREEN_INTERACTIVE : StageDisplayState.NORMAL;
		}
		for each (var o:ScratchObj in stagePane.allObjects()) o.applyFilters();

		if (lp) fixLoadProgressLayout();
		stagePane.updateCostume();
		/*SCRATCH::allow3d _wh*/ { if(isIn3D) render3D.onStageResize(); }
	}

	private function keyDown(evt:KeyboardEvent):void {
		// Escape exists presentation mode.
		if ((evt.charCode == 27) && stagePart.isInPresentationMode()) {
			setPresentationMode(false);
			stagePart.exitPresentationMode();
		}
		// Handle enter key
//		else if(evt.keyCode == 13 && !stage.focus) {
//			stagePart.playButtonPressed(null);
//			evt.preventDefault();
//			evt.stopImmediatePropagation();
//		}
		// Handle ctrl-m and toggle 2d/3d mode
		else if(evt.ctrlKey && evt.charCode == 109) {
			/*SCRATCH::allow3d _wh*/ { isIn3D ? go2D() : go3D(); }
			evt.preventDefault();
			evt.stopImmediatePropagation();
		}
	}

	private function setSmallStageMode(flag:Boolean):void {
		stageIsContracted = flag;
		stagePart.refresh();
		fixLayout();
		libraryPart.refresh();
		tabsPart.refresh();
		stagePane.applyFilters();
		stagePane.updateCostume();
	}

	public function projectLoaded():void {
		removeLoadProgressBox();
		System.gc();
		if (autostart) runtime.startGreenFlags(true);
		saveNeeded = false;

		// translate the blocks of the newly loaded project
		for each (var o:ScratchObj in stagePane.allObjects()) {
			o.updateScriptsAfterTranslation();
		}
	}

	protected function step(e:Event):void {
		// Step the runtime system and all UI components.
		gh.step();
		runtime.stepRuntime();
		Transition.step(null);
		stagePart.step();
		libraryPart.step();
		scriptsPart.step();
		imagesPart.step();
		
		//判断是否可以关闭软件_wh
		if(closeOK == true)
		{
			arduino.dispose();
			stage.nativeWindow.close();
		}
		if(dllOk < 12)
			dllOk --;
		if(dllOk == 5)
		{
			dllOk = 12;
			DialogBox.warnconfirm(OS + " User","please open with administrator privileges", null, app.stage);//软件界面中部显示提示框_wh
		}
		
	}

	public function updateSpriteLibrary(sortByIndex:Boolean = false):void { libraryPart.refresh() }
	public function threadStarted():void { stagePart.threadStarted() }

	public function selectSprite(obj:ScratchObj):void {
		if (isShowing(imagesPart)) imagesPart.editor.shutdown();
		if (isShowing(soundsPart)) soundsPart.editor.shutdown();
		viewedObject = obj;
		libraryPart.refresh();
		tabsPart.refresh();
		if (isShowing(imagesPart)) {
			imagesPart.refresh();
		}
		if (isShowing(soundsPart)) {
			soundsPart.currentIndex = 0;
			soundsPart.refresh();
		}
		if (isShowing(scriptsPart)) {
			scriptsPart.updatePalette();
			scriptsPane.viewScriptsFor(obj);
			scriptsPart.updateSpriteWatermark();
		}
	}

	public function setTab(tabName:String):void {
		if (isShowing(imagesPart)) imagesPart.editor.shutdown();
		if (isShowing(soundsPart)) soundsPart.editor.shutdown();
		hide(scriptsPart);
		hide(imagesPart);
		hide(soundsPart);
		if (!editMode) return;
		if (tabName == 'images') {
			show(imagesPart);
			imagesPart.refresh();
		} else if (tabName == 'sounds') {
			soundsPart.refresh();
			show(soundsPart);
		} else if (tabName && (tabName.length > 0)) {
			tabName = 'scripts';
			scriptsPart.updatePalette();
			scriptsPane.viewScriptsFor(viewedObject);
			scriptsPart.updateSpriteWatermark();
			show(scriptsPart);
		}
		show(tabsPart);
		show(stagePart); // put stage in front
		tabsPart.selectTab(tabName);
		lastTab = tabName;
		if (saveNeeded) setSaveNeeded(true); // save project when switching tabs, if needed (but NOT while loading!)
	}

	public function installStage(newStage:ScratchStage):void {
		var showGreenflagOverlay:Boolean = shouldShowGreenFlag();
		stagePart.installStage(newStage, showGreenflagOverlay);
		selectSprite(newStage);
		libraryPart.refresh();
		setTab('scripts');
		scriptsPart.resetCategory();
		wasEdited = false;
	}

	protected function shouldShowGreenFlag():Boolean {
		return !(autostart || editMode);
	}

	protected function addParts():void {
		initTopBarPart();
		stagePart = getStagePart();
		libraryPart = getLibraryPart();
		tabsPart = new TabsPart(this);
		scriptsPart = new ScriptsPart(this);
		imagesPart = new ImagesPart(this);
		soundsPart = new SoundsPart(this);
		addChild(topBarPart);
		addChild(stagePart);
		addChild(libraryPart);
		addChild(tabsPart);
	}

	protected function getStagePart():StagePart {
		return new StagePart(this);
	}

	protected function getLibraryPart():LibraryPart {
		return new LibraryPart(this);
	}

	public function fixExtensionURL(javascriptURL:String):String {
		return javascriptURL;
	}

	// -----------------------------
	// UI Modes and Resizing
	//------------------------------

	public function setEditMode(newMode:Boolean):void {
		Menu.removeMenusFrom(stage);
		editMode = newMode;
		if (editMode) {
			interp.showAllRunFeedback();
			hide(playerBG);
			show(topBarPart);
			show(libraryPart);
			show(tabsPart);
			setTab(lastTab);
			stagePart.hidePlayButton();
			runtime.edgeTriggersEnabled = true;
		} else {
			addChildAt(playerBG, 0); // behind everything
			playerBG.visible = false;
			hide(topBarPart);
			hide(libraryPart);
			hide(tabsPart);
			setTab(null); // hides scripts, images, and sounds
		}
		stagePane.updateListWatchers();
		show(stagePart); // put stage in front
		fixLayout();
		stagePart.refresh();
	}

	protected function hide(obj:DisplayObject):void { if (obj.parent) obj.parent.removeChild(obj) }
	protected function show(obj:DisplayObject):void { addChild(obj) }
	protected function isShowing(obj:DisplayObject):Boolean { return obj.parent != null }

	public function onResize(e:Event):void {
		fixLayout();
	}

	public function fixLayout():void {
		var w:int = stage.stageWidth;
		var h:int = stage.stageHeight - 1; // fix to show bottom border...

		w = Math.ceil(w / scaleX);
		h = Math.ceil(h / scaleY);

		updateLayout(w, h);
	}

	protected function updateLayout(w:int, h:int):void {
		topBarPart.x = 0;
		topBarPart.y = 0;
		topBarPart.setWidthHeight(w, 28);

		var extraW:int = 2;
		var extraH:int = stagePart.computeTopBarHeight() + 1;
		if (editMode) {
			// adjust for global scale (from browser zoom)

			if (stageIsContracted) {
				stagePart.setWidthHeight(240 + extraW, 180 + extraH, 0.5);
			} else {
				stagePart.setWidthHeight(480 + extraW, 360 + extraH, 1);
			}
			stagePart.x = 5;
			stagePart.y = topBarPart.bottom() + 5;
			fixLoadProgressLayout();
		} else {
			drawBG();
			var pad:int = (w > 550) ? 16 : 0; // add padding for full-screen mode
			var scale:Number = Math.min((w - extraW - pad) / 480, (h - extraH - pad) / 360);
			scale = Math.max(0.01, scale);
			var scaledW:int = Math.floor((scale * 480) / 4) * 4; // round down to a multiple of 4
			scale = scaledW / 480;
			var playerW:Number = (scale * 480) + extraW;
			var playerH:Number = (scale * 360) + extraH;
			stagePart.setWidthHeight(playerW, playerH, scale);
			stagePart.x = int((w - playerW) / 2);
			stagePart.y = int((h - playerH) / 2);
			fixLoadProgressLayout();
			return;
		}
		libraryPart.x = stagePart.x;
		libraryPart.y = stagePart.bottom() + 18;
		libraryPart.setWidthHeight(stagePart.w, h - libraryPart.y);

		tabsPart.x = stagePart.right() + 5;
		tabsPart.y = topBarPart.bottom() + 5;
		tabsPart.fixLayout();

		// the content area shows the part associated with the currently selected tab:
		var contentY:int = tabsPart.y + 27;
		w -= tipsWidth();
		updateContentArea(tabsPart.x, contentY, w - tabsPart.x - 6, h - contentY - 5, h);
	}

	protected function updateContentArea(contentX:int, contentY:int, contentW:int, contentH:int, fullH:int):void {
		imagesPart.x = soundsPart.x = scriptsPart.x = contentX;
		imagesPart.y = soundsPart.y = scriptsPart.y = contentY;
		imagesPart.setWidthHeight(contentW, contentH);
		soundsPart.setWidthHeight(contentW, contentH);
		scriptsPart.setWidthHeight(contentW, contentH);

		if (mediaLibrary) mediaLibrary.setWidthHeight(topBarPart.w, fullH);
		if (frameRateGraph) {
			frameRateGraph.y = stage.stageHeight - frameRateGraphH;
			addChild(frameRateGraph); // put in front
		}

		/*SCRATCH::allow3d _wh*/ { if (isIn3D) render3D.onStageResize(); }
	}

	private function drawBG():void {
		var g:Graphics = playerBG.graphics;
		g.clear();
		g.beginFill(0);
		g.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
	}

	// -----------------------------
	// Translations utilities
	//------------------------------

	public function translationChanged():void {
		// The translation has changed. Fix scripts and update the UI.
		// directionChanged is true if the writing direction (e.g. left-to-right) has changed.
		for each (var o:ScratchObj in stagePane.allObjects()) {
			o.updateScriptsAfterTranslation();
		}
		var uiLayer:Sprite = app.stagePane.getUILayer();
		for (var i:int = 0; i < uiLayer.numChildren; ++i) {
			var lw:ListWatcher = uiLayer.getChildAt(i) as ListWatcher;
			if (lw) lw.updateTranslation();
		}
		topBarPart.updateTranslation();
		stagePart.updateTranslation();
		libraryPart.updateTranslation();
		tabsPart.updateTranslation();
		updatePalette(false);
		imagesPart.updateTranslation();
		soundsPart.updateTranslation();
	}

	// -----------------------------
	// Menus
	//------------------------------
	public function showFileMenu(b:*):void {
		var m:Menu = new Menu(null, 'File', CSS.topBarColor, 28);
		m.addItem('New', createNewProject);
		m.addLine();

		// Derived class will handle this
		addFileMenuItems(b, m);

		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}

	protected function addFileMenuItems(b:*, m:Menu):void {
		m.addItem('Load Project', runtime.selectProjectFile);
		m.addItem('Save Project', exportProjectToFile);
		if (canUndoRevert()) {
			m.addLine();
			m.addItem('Undo Revert', undoRevert);
		} else if (canRevert()) {
			m.addLine();
			m.addItem('Revert', revertToOriginalProject);
		}

		if (b.lastEvent.shiftKey) {
			m.addLine();
			m.addItem('Save Project Summary', saveSummary);
		}
		if (b.lastEvent.shiftKey && jsEnabled) {
			m.addLine();
			m.addItem('Import experimental extension', function():void {
				function loadJSExtension(dialog:DialogBox):void {
					var url:String = dialog.getField('URL').replace(/^\s+|\s+$/g, '');
					if (url.length == 0) return;
					externalCall('ScratchExtensions.loadExternalJS', null, url);
				}
				var d:DialogBox = new DialogBox(loadJSExtension);
				d.addTitle('Load Javascript Scratch Extension');
				d.addField('URL', 120);
				d.addAcceptCancelButtons('Load');
				d.showOnStage(app.stage);
			});
		}
	}

	
	public function showEditMenu(b:*):void {
		var m:Menu = new Menu(null, 'More', CSS.topBarColor, 28);
		m.addItem('Undelete', runtime.undelete, runtime.canUndelete());
		m.addLine();
		m.addItem('Small stage layout', toggleSmallStage, true, stageIsContracted);
		m.addItem('Turbo mode', toggleTurboMode, true, interp.turboMode);
		addEditMenuItems(b, m);
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}

	protected function addEditMenuItems(b:*, m:Menu):void {
		m.addLine();
		m.addItem('Edit block colors', editBlockColors);
	}

	protected function editBlockColors():void {
		var d:DialogBox = new DialogBox();
		d.addTitle('Edit Block Colors');
		d.addWidget(new BlockColorEditor());
		d.addButton('Close', d.cancel);
		d.showOnStage(stage, true);
	}

	//help菜单
	public function showHelpMenu(b:*):void {
		var m:Menu = new Menu(null, 'More', CSS.topBarColor, 28);
		m.addItem('Forum', forum3);
		m.addItem('Software Update', forum4);
		m.addItem('Introduction', intro);
		m.addItem('Configuration System', syscon);
		//navigateToURL(new URLRequest("http://www.cfunworld.com"), "_blank");//论坛外链_wh
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}
	
	//Course菜单
	public function showCourseMenu(b:*):void {
		var m:Menu = new Menu(null, 'More', CSS.topBarColor, 28);
//		m.addItem('Basic Course', forum1);
		m.addItem('Case Works', forum2);
		//navigateToURL(new URLRequest("http://www.cfunworld.com"), "_blank");//论坛外链_wh
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}
	
	//猫友汇菜单_wh
	public function showMYMenu(b:*):void {
		var m:Menu = new Menu(null, 'More', CSS.topBarColor, 28);
		m.addItem('column', forum5);
		m.addItem('Q&A', forum6);
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}
	
	//网址外链_wh
	protected function forum1():void {
		navigateToURL(new URLRequest("http://www.cfunworld.com"), "_blank");//论坛外链_wh
	}
	
	protected function forum2():void {
		navigateToURL(new URLRequest("http://www.youngmaker.com"), "_blank");//论坛外链_wh
	}
	
	protected function forum3():void {
		navigateToURL(new URLRequest("https://scratch.mit.edu"), "_blank");//论坛外链_wh
	}
	protected function forum4():void {
		navigateToURL(new URLRequest("http://www.arduino.cc"), "_blank");//论坛外链_wh
	}
	protected function forum5():void {
		navigateToURL(new URLRequest("http://www.maoyouhui.org/forum.php"), "_blank");//论坛外链_wh
	}
	protected function forum6():void {
		navigateToURL(new URLRequest("http://www.maoyouhui.org/forum.php?mod=forumdisplay&fid=62"), "_blank");//论坛外链_wh
	}
	
	//打开说明_wh
	protected function intro():void {
		var filei:File = new File(File.applicationDirectory.resolvePath("Introduction.pdf").nativePath);
		filei.openWithDefaultApplication();
	}
	
	
	protected function syscon():void {
		var file1:File;
		//*******************************************注意：每个版本需要修改（包括相应文件）*****************************************//
		file1= new File(File.userDirectory.resolvePath("Arduino-Scratch/arduinos/flag_v.txt").nativePath);//在相应目录下寻找或建立dll.txt_wh
		//*******************************************注意：每个版本需要修改（包括相应文件）****************************************//
		var fs:FileStream = new FileStream();
		//将dll文件放在系统目录下_wh
		var OS32:Boolean = Capabilities.supports32BitProcesses;//是否支持32位机_wh
		var OS64:Boolean = Capabilities.supports64BitProcesses;//是否为64位机_wh
		OS = Capabilities.os;//操作系统_wh
		var OS32str:String = "C:/Windows/System32/";
		var OS64str:String = "C:/Windows/SysWOW64/";
		var file2:File;
		var file3:File;
		try
		{
			file3= new File(File.applicationDirectory.resolvePath("avrtool/pthreadVC2.dll").nativePath);//_wh
			if(OS64)
				file2= new File(File.applicationDirectory.resolvePath(OS64str+"pthreadVC2.dll").nativePath);//_wh
			else
				file2= new File(File.applicationDirectory.resolvePath(OS32str+"pthreadVC2.dll").nativePath);//_wh
			if(file2.exists)
			{
				dllOk ++;
				file3.copyTo(file2,true);
			}
			else
			{
				file3.copyTo(file2,true);
				dllOk ++;
			}
		}
		catch(Error)
		{
			;
		}
		try
		{
			file3= new File(File.applicationDirectory.resolvePath("avrtool/msvcr100d.dll").nativePath);//_wh
			if(OS64)
				file2= new File(File.applicationDirectory.resolvePath(OS64str+"msvcr100d.dll").nativePath);//_wh
			else
				file2= new File(File.applicationDirectory.resolvePath(OS32str+"msvcr100d.dll").nativePath);//_wh
			if(file2.exists)
			{
				dllOk ++;
				file3.copyTo(file2,true);
			}
			else
			{
				file3.copyTo(file2,true);
				dllOk ++;
			}
		}
		catch(Error)
		{
			;
		}
		try
		{
			file3= new File(File.applicationDirectory.resolvePath("avrtool/msvcr120d.dll").nativePath);//_wh
			if(OS64)
				file2= new File(File.applicationDirectory.resolvePath(OS64str+"msvcr120d.dll").nativePath);//_wh
			else
				file2= new File(File.applicationDirectory.resolvePath(OS32str+"msvcr120d.dll").nativePath);//_wh
			if(file2.exists)
			{
				dllOk ++;
				file3.copyTo(file2,true);
			}
			else
			{
				file3.copyTo(file2,true);
				dllOk ++;
			}
		}
		catch(Error)
		{
			;
		}
		try
		{
			if(OS64)
			{
				file3= new File(File.applicationDirectory.resolvePath("avrtool/win7/msvcr100.dll").nativePath);//_wh
				file2= new File(File.applicationDirectory.resolvePath(OS64str+"msvcr100.dll").nativePath);//_wh
			}
			else
			{
				file3= new File(File.applicationDirectory.resolvePath("avrtool/xp/msvcr100.dll").nativePath);//_wh
				file2= new File(File.applicationDirectory.resolvePath(OS32str+"msvcr100.dll").nativePath);//_wh
			}
			if(file2.exists)
			{
				dllOk ++;
				file3.copyTo(file2,true);
			}
			else
			{
				file3.copyTo(file2,true);
				dllOk ++;
			}
		}
		catch(Error)
		{
			;
		}
		if(dllOk > 13)
		{
			fs.open(file1,FileMode.WRITE);
			fs.position = 0;
			fs.writeUTFBytes("1");
			fs.close();
		}
	}
	
	//串口检测，输出扫描到的所有有效串口号_wh
	public function checkUART():Array
	{
		var comArray:Array = new Array();
		if(comTrue)
			arduino.close();
		for(var i:int =1;i<=32;i++)//COM口号限制量增加到32_wh
		{
			if(arduino.isSupported("COM"+i))
			{
				comArray.push("COM"+i);
			}
		}
		return comArray;
	}
	
	//串口数据接收事件处理_wh
	public const uartDataID_checkUartAvail:int     = 0x01;
	public var processUartReadData_Flag:Boolean    = false;
	
	//接收到串口中断
	public function fncArduinoData(aEvt: ArduinoConnectorEvent):void
	{
		uartDetectStatustimerStop = 0x01;
		processUartReadData_Flag = true;
		app.comCOMing = 0x00;
		
		Para_UartData();
	}
	
	public function Para_UartData():void
	{
		var paraDataBuffer:Array  = new Array();
		try
		{
			comDataArrayOld = comDataArrayOld.concat(arduino.readBytesAsArray());//将接收到的数据放在comDataArrayOld数组中_wh
		}
		catch(Error)
		{
			return;
		}
	
		app.comCOMing = 0x00;
		
		while(1)
		{
			comDataArray.length =0;
			//将接收到的ASCII码字符型转成数值型_wh
			for(var i:int = 0; i < comDataArrayOld.length; i++)
				comDataArray[i] = comDataArrayOld[i].charCodeAt(0);
			//接收通信协议：0xee 0x66; 0xXX（类型）; 0xXX（编号）; 0xXX...（值）_wh
			
			if((comDataArray[0] == 0xfe) && (comDataArray[1] == 0xfd) && (comDataArray[comDataArray.length-2] == 0xfe) && (comDataArray[comDataArray.length-1] == 0xfb))//comDataArray中为ASCII码字符型，判断不等
			{
				if (comDataArray[2] == comDataArray.length)
				{
					if(comDataArray[3] == uartDataID_checkUartAvail)
					{
						for(var j:int = 0; j < comDataArrayOld.length-5; j++)
						{
							paraDataBuffer[j] = comDataArray[j+4];
						}
						paraUartData_OnTick(paraDataBuffer);
					}
					break;
				}				
				//数据左移一位_wh
				if(comDataArray.length >= 2)
					comDataArrayOld.shift();//数组整体前移一位_wh
					//数据未接收全_wh
				else
					break;
			}
			
			if((comDataArray[0] == 0xee) || (comDataArrayOld.length == 0))//comDataArray中为ASCII码字符型，判断不等？_wh
			{
				if(comDataArray[1] == 0x66)
				{
					//根据类别进行初步数据有效性判断_wh
					switch(comDataArray[2])
					{
						case CFunPrims.ID_ReadDigital:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadAnalog:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadAFloat:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadPFloat:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadCap:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadTRACK:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadAVOID:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadULTR:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_ReadPOWER:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						case CFunPrims.ID_READFRAREDR:if(comDataArray.length >= 8) comRevFlag = true;break;//数据接收完整判断_wh
						default:break;
					}
					break;
				}
				//数据左移一位_wh
				if(comDataArray.length >= 2)
					comDataArrayOld.shift();//数组整体前移一位_wh
					//数据未接收全_wh
				else
					break;
			}
			else
			{
				comDataArrayOld.shift();//数组整体前移一位_wh
			}
		}
	}
	
	public var arduinoLightValue:int      = 0x00;  //板载sensor数据
	public var arduinoSlideValue:int      = 0x00;
	public var arduinoSoundValue:int      = 0x00;
	public var arduinoUltrasonicValue:int = 0x00;
	
	public function paraUartData_OnTick(data:Array):void
	{		
		for(var i:int = 0x00;i < data.length;i++)
		{
			if(isNaN(data[i]))
			{
				data[i] = 0;
			}
		}
		arduinoSoundValue = (int)(data[0] * 256 + data[1])* 3  >> 4;	
		arduinoSlideValue = (int)(data[2] * 256 + data[3])*100 >>10;	
		arduinoLightValue = (int)(data[4] * 256 + data[5])*100 >>10;	
		
		if(arduinoSoundValue >= 100)
		{
			arduinoSoundValue = 100;
		}
//		arduinoLightValue = (data[6] * 256 + data[7])*100 >>10;	
//		arduinoLightValue = (data[8] * 256 + data[9])*100 >>10;	
		
		arduinoUltrasonicValue = (data[10] <<24 + data[11] << 16 + data[12] << 8 +data[13])	
	}
	
	
	//主菜单增加COM项_wh
	public function showCOMMenu(b:*):void {
		if(showCOMFlag)
			return;
		showCOMFlag = true;
		var m:Menu = new Menu(null, 'COM', CSS.topBarColor, 28);
		
		if(cmdBackNum == 0)//固件下载过程中不允许操作COM口_wh
		{
			var comArrays:Array = new Array();
			//COM口未开启_wh
			if(comTrue == false){
				
				comArrays = checkUART();//获取扫描到的COM口编号(可用未开启的)_wh
				for(var i:int = 0; i < comArrays.length; i++)//显示扫描到的COM号_wh
				{
					//comID = comArrays[i];//当前显示ID号赋给comID作为全局变量_wh
					switch(comArrays[i])
					{
						case 'COM1':m.addItem(comArrays[i], comOpen1);break;//选中则开启_wh
						case 'COM2':m.addItem(comArrays[i], comOpen2);break;//选中则开启_wh
						case 'COM3':m.addItem(comArrays[i], comOpen3);break;//选中则开启_wh
						case 'COM4':m.addItem(comArrays[i], comOpen4);break;//选中则开启_wh
						case 'COM5':m.addItem(comArrays[i], comOpen5);break;//选中则开启_wh
						case 'COM6':m.addItem(comArrays[i], comOpen6);break;//选中则开启_wh
						case 'COM7':m.addItem(comArrays[i], comOpen7);break;//选中则开启_wh
						case 'COM8':m.addItem(comArrays[i], comOpen8);break;//选中则开启_wh
						case 'COM9':m.addItem(comArrays[i], comOpen9);break;//选中则开启_wh
						case 'COM10':m.addItem(comArrays[i], comOpen10);break;//选中则开启_wh
						case 'COM11':m.addItem(comArrays[i], comOpen11);break;//选中则开启_wh
						case 'COM12':m.addItem(comArrays[i], comOpen12);break;//选中则开启_wh
						case 'COM13':m.addItem(comArrays[i], comOpen13);break;//选中则开启_wh
						case 'COM14':m.addItem(comArrays[i], comOpen14);break;//选中则开启_wh
						case 'COM15':m.addItem(comArrays[i], comOpen15);break;//选中则开启_wh
						case 'COM16':m.addItem(comArrays[i], comOpen16);break;//选中则开启_wh
						case 'COM17':m.addItem(comArrays[i], comOpen17);break;//选中则开启_wh
						case 'COM18':m.addItem(comArrays[i], comOpen18);break;//选中则开启_wh
						case 'COM19':m.addItem(comArrays[i], comOpen19);break;//选中则开启_wh
						case 'COM20':m.addItem(comArrays[i], comOpen20);break;//选中则开启_wh
						case 'COM21':m.addItem(comArrays[i], comOpen21);break;//选中则开启_wh
						case 'COM22':m.addItem(comArrays[i], comOpen22);break;//选中则开启_wh
						case 'COM23':m.addItem(comArrays[i], comOpen23);break;//选中则开启_wh
						case 'COM24':m.addItem(comArrays[i], comOpen24);break;//选中则开启_wh
						case 'COM25':m.addItem(comArrays[i], comOpen25);break;//选中则开启_wh
						case 'COM26':m.addItem(comArrays[i], comOpen26);break;//选中则开启_wh
						case 'COM27':m.addItem(comArrays[i], comOpen27);break;//选中则开启_wh
						case 'COM28':m.addItem(comArrays[i], comOpen28);break;//选中则开启_wh
						case 'COM29':m.addItem(comArrays[i], comOpen29);break;//选中则开启_wh
						case 'COM30':m.addItem(comArrays[i], comOpen30);break;//选中则开启_wh
						case 'COM31':m.addItem(comArrays[i], comOpen31);break;//选中则开启_wh
						case 'COM32':m.addItem(comArrays[i], comOpen32);break;//选中则开启_wh
						default:break;
					}
				}
			}
			//COM口已断开
			else if(comStatus != 0x00){
				arduino.close();
				xuhy_test_log("showCOMMenu comStatus != 0x00");
				
				var ts:Number = getTimer();
				while((getTimer()-ts) < 50)
					;
				comTrue = false;
				comDataArrayOld.splice();//数组清零_wh
				comArrays = checkUART();//获取扫描到的COM口编号(可用未开启的)_wh
				for(var i:int = 0; i < comArrays.length; i++){//显示扫描到的COM号_wh	
					if(comArrays[i] == comIDTrue){		
						if(arduino.connect(comIDTrue,115200)){//判断是否可用_wh
							comTrue = true;
							m.addItem(comIDTrue, comClose, true, true);//选中则关闭；只显示选中的COM口且前面勾对号(最后一个true)_wh
							setAutoConnect();				
						}
						else{
							arduino.close();//重新关闭_wh
							CFunConCir(0);
						}
					}
					else{
						switch(comArrays[i]){//最多显示到32_wh
							case 'COM1':m.addItem(comArrays[i], comOpen1);break;//选中则开启_wh
							case 'COM2':m.addItem(comArrays[i], comOpen2);break;//选中则开启_wh
							case 'COM3':m.addItem(comArrays[i], comOpen3);break;//选中则开启_wh
							case 'COM4':m.addItem(comArrays[i], comOpen4);break;//选中则开启_wh
							case 'COM5':m.addItem(comArrays[i], comOpen5);break;//选中则开启_wh
							case 'COM6':m.addItem(comArrays[i], comOpen6);break;//选中则开启_wh
							case 'COM7':m.addItem(comArrays[i], comOpen7);break;//选中则开启_wh
							case 'COM8':m.addItem(comArrays[i], comOpen8);break;//选中则开启_wh
							case 'COM9':m.addItem(comArrays[i], comOpen9);break;//选中则开启_wh
							case 'COM10':m.addItem(comArrays[i], comOpen10);break;//选中则开启_wh
							case 'COM11':m.addItem(comArrays[i], comOpen11);break;//选中则开启_wh
							case 'COM12':m.addItem(comArrays[i], comOpen12);break;//选中则开启_wh
							case 'COM13':m.addItem(comArrays[i], comOpen13);break;//选中则开启_wh
							case 'COM14':m.addItem(comArrays[i], comOpen14);break;//选中则开启_wh
							case 'COM15':m.addItem(comArrays[i], comOpen15);break;//选中则开启_wh
							case 'COM16':m.addItem(comArrays[i], comOpen16);break;//选中则开启_wh
							case 'COM17':m.addItem(comArrays[i], comOpen17);break;//选中则开启_wh
							case 'COM18':m.addItem(comArrays[i], comOpen18);break;//选中则开启_wh
							case 'COM19':m.addItem(comArrays[i], comOpen19);break;//选中则开启_wh
							case 'COM20':m.addItem(comArrays[i], comOpen20);break;//选中则开启_wh
							case 'COM21':m.addItem(comArrays[i], comOpen21);break;//选中则开启_wh
							case 'COM22':m.addItem(comArrays[i], comOpen22);break;//选中则开启_wh
							case 'COM23':m.addItem(comArrays[i], comOpen23);break;//选中则开启_wh
							case 'COM24':m.addItem(comArrays[i], comOpen24);break;//选中则开启_wh
							case 'COM25':m.addItem(comArrays[i], comOpen25);break;//选中则开启_wh
							case 'COM26':m.addItem(comArrays[i], comOpen26);break;//选中则开启_wh
							case 'COM27':m.addItem(comArrays[i], comOpen27);break;//选中则开启_wh
							case 'COM28':m.addItem(comArrays[i], comOpen28);break;//选中则开启_wh
							case 'COM29':m.addItem(comArrays[i], comOpen29);break;//选中则开启_wh
							case 'COM30':m.addItem(comArrays[i], comOpen30);break;//选中则开启_wh
							case 'COM31':m.addItem(comArrays[i], comOpen31);break;//选中则开启_wh
							case 'COM32':m.addItem(comArrays[i], comOpen32);break;//选中则开启_wh
							default:break;
						}
					}
				}
			}
			else{
				m.addItem(comIDTrue, comClose, true, true);
				xuhy_test_log("showCOMMenu comStatus = 0x00");
			}
			m.addLine();
			
			//蓝牙通信模式_wh
			if(blueFlag == false)
				m.addItem("Bluetooth", BlueOpen);
			else
				m.addItem("Bluetooth", BlueClose, true, true);
			
			m.addLine();
			
			m.addItem("Firmware", dofirm);//固件更新_wh
			m.addLine();
			m.addItem("Drive", dodrive);//固件更新_wh
			m.addLine();
		}
		
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
		
		if(UDFlag == false)
		{
			UDFlag = true;
			//上传固件等待文本框_wh
			UpDialog.addTitle('Upload');
			UpDialog.addButton('Close',cancel);
			UpDialog.addText(Translator.map("uploading") + " ... ");
		}
		
		showCOMFlag = false;
	}
	
	protected function BlueOpen():void {
		blueFlag = true;
	}
	
	protected function BlueClose():void {
		blueFlag = false;
	}
	
	public function cancel():void {
	
		UpDialog.cancel();
		if((cmdBackNum < 70) && (cmdBackNum != 0))
			cmdBackNum = 70;//表示停止_wh
	}
	
	protected function dodrive():void {
		file0= new File(File.applicationDirectory.resolvePath("avrtool").nativePath);//在相应目录下寻找或建立cmd.bat_wh
		var file:File = new File();
		file = file.resolvePath(file0.nativePath+"/cmd.exe");//调用cmd.exe_wh
		nativePSInfo.executable = file;
		process.start(nativePSInfo);//执行dos命令_wh
		process.standardInput.writeUTFBytes("cd /d "+file0.nativePath+"\r\n");//cmd命令路径，回车符，/r/n_wh
		process.standardInput.writeUTFBytes("CH341SER"+"\r\n");//avrdude命令行_wh
		process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//cmd返回数据处理事件_wh	
		DriveFlag = 1;
	}
	
	//固件烧入_wh
	protected function dofirm():void {
		//烧入固件前先判断串口，未打开则之间退出，打开则先关闭（否则串口被占用）_wh
		if(comTrue)
		{
			arduino.close();
			clearInterval(IntervalID);
			CFunConCir(0);
			comStatus = 0x01;
		}
		else
		{
			DialogBox.warnconfirm(Translator.map("error about firmware"),Translator.map("please open the COM"), null, app.stage);//软件界面中部显示提示框_wh
			return;
		}
		
		file0= new File(File.applicationDirectory.resolvePath("avrtool").nativePath);//在相应目录下寻找或建立cmd.bat_wh
		var file:File = new File();
		file = file.resolvePath(file0.nativePath+"/cmd.exe");//调用cmd.exe_wh
		nativePSInfo.executable = file;
		process.start(nativePSInfo);//执行dos命令_wh
		process.standardInput.writeUTFBytes("cd /d "+file0.nativePath+"\r\n");//cmd命令路径，回车符，/r/n_wh
		process.standardInput.writeUTFBytes("avrdude -p m328p -c arduino -b 115200 -P "+comIDTrue+ " -U flash:w:S4A.hex"+"\r\n");//avrdude命令行_wh
		
		//等待文本框提示_wh
		UpDialog.setText(Translator.map("uploading") + " ... ");
		UpDialog.showOnStage(stage);
		ArduinoFirmFlag = 0;
		
		process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//cmd返回数据处理事件_wh	
		delay1sTimer.start();//开启定时器,2s后开启cmd监听，跳过前两句返回信息_wh
		cmdBackNum = 1;
	}
	
	protected function onTick(event:TimerEvent):void  
	{ 
		cmdBackNum ++;
		if(app.ArduinoRPFlag == true)
		{
			if(cmdBackNum == 71)//70s
			{
				{
					process.exit(nativePSInfo);//退出cmd.exe_wh
					process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//移除侦听器_wh
					process2.start(nativePSInfo);//执行dos命令_wh
					process2.standardInput.writeUTFBytes("taskkill /f /im ArduinoUploader.exe /t"+"\r\n");//强行关闭avrdude进程_wh
					UpDialog.setText(Translator.map("upload failed"));
				}
			}
			if(cmdBackNum == 73)//72s
			{
				cmdBackNum = 0;
				process2.exit(nativePSInfo);
				delay1sTimer.reset();
				app.ArduinoRPFlag = false;
				arduino.connect(comIDTrue,115200);//重新开启串口_wh
			}
		}
		else
		{
			if(cmdBackNum == 71)//70s
			{
				{
					process.exit(nativePSInfo);//退出cmd.exe_wh
					process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//移除侦听器_wh
					process2.start(nativePSInfo);//执行dos命令_wh
					process2.standardInput.writeUTFBytes("taskkill /f /im avrdude.exe /t"+"\r\n");//强行关闭avrdude进程_wh
					UpDialog.setText(Translator.map("upload failed"));
				}
			}
			if(cmdBackNum == 73)//72s
			{
				cmdBackNum = 0;
				process2.exit(nativePSInfo);
				delay1sTimer.reset();
				arduino.connect(comIDTrue,115200);//重新开启串口_wh
			}
		}
	}
	
	//40s长时间没收到信息，说明下载出现问题，进行停止措施，该函数一般不会执行到_wh
	protected function onTimerComplete(event:TimerEvent):void 
	{ 
		process2.exit(nativePSInfo);
		delay1sTimer.reset();
		app.ArduinoRPFlag = false;
		cmdBackNum = 0;
		arduino.connect(comIDTrue,115200);//重新开启串口_wh
	} 
	
	//cmd返回数据处理事件函数_wh
	private var uploadFirmOK_setUartAutoConnect_Flag:Boolean = false;
	public function cmdDataHandler(event:ProgressEvent):void {
		var str:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable); 
		trace(str);
		if(DriveFlag)
		{
			if(DriveFlag == 2)
			{
				process.exit(nativePSInfo);//退出cmd.exe_wh
				process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//移除侦听器_wh
				DriveFlag = 0;
			}
			if(str.indexOf("CH341SER") != -1)
			{
				DriveFlag = 2;
			}	
		}
		else
		{
			if(app.ArduinoRPFlag == true)
			{
				CFunConCir(0);
				if(str.indexOf("Compiliation:") != -1)
				{
					UpDialog.setText(Translator.map("uploading") + " ... ");
				}
				if(str.indexOf("Writing | ") != -1)
				{
					UpDialog.setText(Translator.map("upload success"));
					process.exit(nativePSInfo);//退出cmd.exe_wh
					process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//移除侦听器_wh
					var ts:Number = getTimer();
					delay1sTimer.reset();
					cmdBackNum = 0;
					app.ArduinoRPFlag = false;
					comStatus = 0x00;
					while((getTimer()-ts) < 50)
						;
					arduino.connect(comIDTrue,115200);//重新开启串口_wh
				}
			}
			else
			{
				if(str.indexOf("avrtool>") != -1)
				{
					if(ArduinoFirmFlag)
					{
						if(cmdBackNum < 4)
						{
							cmdBackNum = 70;//表示停止_wh
							ArduinoFirmFlag = 9;
						}
						else
						{
							if(ArduinoFirmFlag < 9)
							{
								UpDialog.setText(Translator.map("upload success"));
								process.exit(nativePSInfo);//退出cmd.exe_wh
								process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, cmdDataHandler);//移除侦听器_wh
								var ts:Number = getTimer();
								delay1sTimer.reset();
								uploadFirmOK_setUartAutoConnect_Flag = true;
								cmdBackNum = 0;
								while((getTimer()-ts) < 50)
									;
								setAutoConnect();
							}
						}
					}
					else
						ArduinoFirmFlag ++;
				}
			}
		}
	}
	
	//显示并打开选择的COM口
	private const readoutFormat1:TextFormat = new TextFormat(CSS.font, 10, CSS.textColor);
	protected function comOpen1():void {
		//还没找到显示COM口打开的方法_wh
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM1';
		setAutoConnect();
	}
	protected function comOpen2():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM2';
		setAutoConnect();
	}
	protected function comOpen3():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM3';
		setAutoConnect();
	}
	protected function comOpen4():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM4';
		setAutoConnect();
	}
	protected function comOpen5():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM5';
		setAutoConnect();
	}
	protected function comOpen6():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM6';
		setAutoConnect();
	}
	protected function comOpen7():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM7';
		setAutoConnect();
	}
	protected function comOpen8():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM8';
		setAutoConnect();
	}
	protected function comOpen9():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM9';
		setAutoConnect();
	}
	protected function comOpen10():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM10';
		setAutoConnect();
	}
	protected function comOpen11():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM11';	
		setAutoConnect();
	}
	protected function comOpen12():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM12';
		setAutoConnect();
	}
	protected function comOpen13():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM13';
		setAutoConnect();
	}
	protected function comOpen14():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM14';
		setAutoConnect();
	}
	protected function comOpen15():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM15';
		setAutoConnect();
	}
	protected function comOpen16():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM16';
		setAutoConnect();
	}
	
	protected function comOpen17():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM17';
		setAutoConnect();
	}
	
	protected function comOpen18():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM18';
		setAutoConnect();
	}
	
	protected function comOpen19():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM19';
		setAutoConnect();
	}
	
	protected function comOpen20():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM20';
		setAutoConnect();
	}
	
	protected function comOpen21():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM21';
		setAutoConnect();
	}
	
	protected function comOpen22():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM22';
		setAutoConnect();
	}
	
	protected function comOpen23():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM23';
		setAutoConnect();
	}
	
	protected function comOpen24():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM24';
		setAutoConnect();
	}
	
	protected function comOpen25():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM25';
		setAutoConnect();
	}
	
	protected function comOpen26():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM26';
		setAutoConnect();
	}
	
	protected function comOpen27():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM27';
		setAutoConnect();
	}
	
	protected function comOpen28():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM28';
		setAutoConnect();
	}
	
	
	protected function comOpen29():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM29';
		setAutoConnect();
	}
	
	protected function comOpen30():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM30';
		setAutoConnect();
	}
	
	
	protected function comOpen31():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM31';
		setAutoConnect();
	}
	
	protected function comOpen32():void {
		comTrue = true;//COM口开启标志量赋值_wh
		comIDTrue = 'COM32';
		setAutoConnect();
	}

	
	//
	private function SetConnectComIDText(s:String):void{
		
/*		connectComIDText.x = TopBarPart.UartComIDTextX;
		connectComIDText.y = TopBarPart.UartComIDTextY;
		connectComIDText.text = s;
		connectComIDText.textColor =  CSS.white;
		addChild(connectComIDText);*/
	}
	
	private function RemoveConnectComIDText():void{
		
/*		connectComIDText.x = TopBarPart.UartComIDTextX;
		connectComIDText.y = TopBarPart.UartComIDTextY;
		connectComIDText.text = ' ';
		addChild(connectComIDText);*/
	}
	
	
	//显示并关闭选择的COM口
	protected function comClose():void {
		comTrue = false;//COM口开启标志量赋值_wh
		arduino.writeString('UART Close '+comIDTrue+'\n');//_wh
		arduino.flush();	//清除缓存_wh
		arduino.close();	//关闭COM口_wh
		CFunConCir(0);
		clearInterval(IntervalID);
//		IntervalID = 0x00;
//		RemoveConnectComIDText();
		readCDFlag = false;//通信丢失提示框标志清零_wh
	}
	
	protected function canExportInternals():Boolean {
		return false;
	}

	private function showAboutDialog():void {
		DialogBox.notify(
			'Scratch 2.0 ' + versionString,
			'\n\nCopyright © 2012 MIT Media Laboratory' +
			'\nAll rights reserved.' +
			'\n\nPlease do not distribute!', stage);
	}

	protected function createNewProject(ignore:* = null):void {
		function clearProject():void {
			startNewProject('', '');
			setProjectName('Untitled');
			topBarPart.refresh();
			stagePart.refresh();
		}
		saveProjectAndThen(clearProject);
	}

	protected function saveProjectAndThen(postSaveAction:Function = null):void {
		// Give the user a chance to save their project, if needed, then call postSaveAction.
		function doNothing():void {}
		function cancel():void { d.cancel(); }
		function proceedWithoutSaving():void { d.cancel(); postSaveAction() }
		function save():void {
			d.cancel();
			exportProjectToFile(); // if this succeeds, saveNeeded will become false
			if (!saveNeeded) postSaveAction();
		}
		if (postSaveAction == null) postSaveAction = doNothing;
		if (!saveNeeded) {
			postSaveAction();
			return;
		}
		var d:DialogBox = new DialogBox();
		d.addTitle('Save project?');
		d.addButton('Save', save);
		d.addButton('Don\'t save', proceedWithoutSaving);
		d.addButton('Cancel', cancel);
		d.showOnStage(stage);
	}

	protected function exportProjectToFile(fromJS:Boolean = false):void {
		function squeakSoundsConverted():void {
			scriptsPane.saveScripts(false);
			var defaultName:String = (projectName().length > 0) ? projectName() + '.sb2' : 'project.sb2';
			var zipData:ByteArray = projIO.encodeProjectAsZipFile(stagePane);
			var file:FileReference = new FileReference();
			file.addEventListener(Event.COMPLETE, fileSaved);
			file.addEventListener(Event.CANCEL, fileNoSaved);//不保存时序清零状态量_wh
			file.save(zipData, fixFileName(defaultName));
		}
		function fileSaved(e:Event):void {
			if (!fromJS) setProjectName(e.target.name);
			if(closeWait == true)//关闭按钮后等待保存完关闭软件_wh
				closeOK = true;
		}
		//不保存时序清零状态量_wh
		function fileNoSaved(e:Event):void {
			closeWait = false;//关闭按钮后等待保存完关闭软件_wh
		}
		if (loadInProgress) return;
		var projIO:ProjectIO = new ProjectIO(this);
		projIO.convertSqueakSounds(stagePane, squeakSoundsConverted);
	}

	public static function fixFileName(s:String):String {
		// Replace illegal characters in the given string with dashes.
		const illegal:String = '\\/:*?"<>|%';
		var result:String = '';
		for (var i:int = 0; i < s.length; i++) {
			var ch:String = s.charAt(i);
			if ((i == 0) && ('.' == ch)) ch = '-'; // don't allow leading period
			result += (illegal.indexOf(ch) > -1) ? '-' : ch;
		}
		return result;
	}

	public function saveSummary():void {
		var name:String = (projectName() || "project") + ".txt";
		var file:FileReference = new FileReference();
		file.save(stagePane.getSummary(), fixFileName(name));
	}

	public function toggleSmallStage():void {
		setSmallStageMode(!stageIsContracted);
	}

	public function toggleTurboMode():void {
		interp.turboMode = !interp.turboMode;
		stagePart.refresh();
	}

	public function handleTool(tool:String, evt:MouseEvent):void { }

	public function showBubble(text:String, x:* = null, y:* = null, width:Number = 0):void {
		if (x == null) x = stage.mouseX;
		if (y == null) y = stage.mouseY;
		gh.showBubble(text, Number(x), Number(y), width);
	}

	// -----------------------------
	// Project Management and Sign in
	//------------------------------

	public function setLanguagePressed(b:IconButton):void {
		function setLanguage(lang:String):void {
			Translator.setLanguage(lang);
			languageChanged = true;
		}
		if (Translator.languages.length == 0) return; // empty language list
		var m:Menu = new Menu(setLanguage, 'Language', CSS.topBarColor, 28);
		if (b.lastEvent.shiftKey) {
			m.addItem('import translation file');
			m.addItem('set font size');
			m.addLine();
		}
		for each (var entry:Array in Translator.languages) {
			m.addItem(entry[1], entry[0]);
		}
		var p:Point = b.localToGlobal(new Point(0, 0));
		m.showOnStage(stage, b.x, topBarPart.bottom() - 1);
	}

	public function startNewProject(newOwner:String, newID:String):void {
		runtime.installNewProject();
		projectOwner = newOwner;
		projectID = newID;
		projectIsPrivate = true;
		loadInProgress = false;
	}

	// -----------------------------
	// Save status
	//------------------------------

	public var saveNeeded:Boolean;

	public function setSaveNeeded(saveNow:Boolean = false):void {
		saveNow = false;
		// Set saveNeeded flag and update the status string.
		saveNeeded = true;
		if (!wasEdited) saveNow = true; // force a save on first change
		clearRevertUndo();
	}

	protected function clearSaveNeeded():void {
		// Clear saveNeeded flag and update the status string.
		function twoDigits(n:int):String { return ((n < 10) ? '0' : '') + n }
		saveNeeded = false;
		wasEdited = true;
	}

	// -----------------------------
	// Project Reverting
	//------------------------------

	protected var originalProj:ByteArray;
	private var revertUndo:ByteArray;

	public function saveForRevert(projData:ByteArray, isNew:Boolean, onServer:Boolean = false):void {
		originalProj = projData;
		revertUndo = null;
	}

	protected function doRevert():void {
		runtime.installProjectFromData(originalProj, false);
	}

	protected function revertToOriginalProject():void {
		function preDoRevert():void {
			revertUndo = new ProjectIO(Scratch.app).encodeProjectAsZipFile(stagePane);
			doRevert();
		}
		if (!originalProj) return;
		DialogBox.confirm('Throw away all changes since opening this project?', stage, preDoRevert);
	}

	protected function undoRevert():void {
		if (!revertUndo) return;
		runtime.installProjectFromData(revertUndo, false);
		revertUndo = null;
	}

	protected function canRevert():Boolean { return originalProj != null }
	protected function canUndoRevert():Boolean { return revertUndo != null }
	private function clearRevertUndo():void { revertUndo = null }

	public function addNewSprite(spr:ScratchSprite, showImages:Boolean = false, atMouse:Boolean = false):void {
		var c:ScratchCostume, byteCount:int;
		for each (c in spr.costumes) {
			if (!c.baseLayerData) c.prepareToSave()
			byteCount += c.baseLayerData.length;
		}
		if (!okayToAdd(byteCount)) return; // not enough room
		spr.objName = stagePane.unusedSpriteName(spr.objName);
		spr.indexInLibrary = 1000000; // add at end of library
		spr.setScratchXY(int(200 * Math.random() - 100), int(100 * Math.random() - 50));
		if (atMouse) spr.setScratchXY(stagePane.scratchMouseX(), stagePane.scratchMouseY());
		stagePane.addChild(spr);
		selectSprite(spr);
		setTab(showImages ? 'images' : 'scripts');
		setSaveNeeded(true);
		libraryPart.refresh();
		for each (c in spr.costumes) {
			if (ScratchCostume.isSVGData(c.baseLayerData)) c.setSVGData(c.baseLayerData, false);
		}
	}

	public function addSound(snd:ScratchSound, targetObj:ScratchObj = null):void {
		if (snd.soundData && !okayToAdd(snd.soundData.length)) return; // not enough room
		if (!targetObj) targetObj = viewedObj();
		snd.soundName = targetObj.unusedSoundName(snd.soundName);
		targetObj.sounds.push(snd);
		setSaveNeeded(true);
		if (targetObj == viewedObj()) {
			soundsPart.selectSound(snd);
			setTab('sounds');
		}
	}

	public function addCostume(c:ScratchCostume, targetObj:ScratchObj = null):void {
		if (!c.baseLayerData) c.prepareToSave();
		if (!okayToAdd(c.baseLayerData.length)) return; // not enough room
		if (!targetObj) targetObj = viewedObj();
		c.costumeName = targetObj.unusedCostumeName(c.costumeName);
		targetObj.costumes.push(c);
		targetObj.showCostumeNamed(c.costumeName);
		setSaveNeeded(true);
		if (targetObj == viewedObj()) setTab('images');
	}

	public function okayToAdd(newAssetBytes:int):Boolean {
		// Return true if there is room to add an asset of the given size.
		// Otherwise, return false and display a warning dialog.
		const assetByteLimit:int = 50 * 1024 * 1024; // 50 megabytes
		var assetByteCount:int = newAssetBytes;
		for each (var obj:ScratchObj in stagePane.allObjects()) {
			for each (var c:ScratchCostume in obj.costumes) {
				if (!c.baseLayerData) c.prepareToSave();
				assetByteCount += c.baseLayerData.length;
			}
			for each (var snd:ScratchSound in obj.sounds) assetByteCount += snd.soundData.length;
		}
		if (assetByteCount > assetByteLimit) {
			var overBy:int = Math.max(1, (assetByteCount - assetByteLimit) / 1024);
			DialogBox.notify(
				'Sorry!',
				'Adding that media asset would put this project over the size limit by ' + overBy + ' KB\n' +
				'Please remove some costumes, backdrops, or sounds before adding additional media.',
				stage);
			return false;
		}
		return true;
	}
	// -----------------------------
	// Flash sprite (helps connect a sprite on the stage with a sprite library entry)
	//------------------------------

	public function flashSprite(spr:ScratchSprite):void {
		function doFade(alpha:Number):void { box.alpha = alpha }
		function deleteBox():void { if (box.parent) { box.parent.removeChild(box) }}
		var r:Rectangle = spr.getVisibleBounds(this);
		var box:Shape = new Shape();
		box.graphics.lineStyle(3, CSS.overColor, 1, true);
		box.graphics.beginFill(0x808080);
		box.graphics.drawRoundRect(0, 0, r.width, r.height, 12, 12);
		box.x = r.x;
		box.y = r.y;
		addChild(box);
		Transition.cubic(doFade, 1, 0, 0.5, deleteBox);
	}

	// -----------------------------
	// Download Progress
	//------------------------------

	public function addLoadProgressBox(title:String):void {
		removeLoadProgressBox();
		lp = new LoadProgress();
		lp.setTitle(title);
		stage.addChild(lp);
		fixLoadProgressLayout();
	}

	public function removeLoadProgressBox():void {
		if (lp && lp.parent) lp.parent.removeChild(lp);
		lp = null;
	}

	private function fixLoadProgressLayout():void {
		if (!lp) return;
		var p:Point = stagePane.localToGlobal(new Point(0, 0));
		lp.scaleX = stagePane.scaleX;
		lp.scaleY = stagePane.scaleY;
		lp.x = int(p.x + ((stagePane.width - lp.width) / 2));
		lp.y = int(p.y + ((stagePane.height - lp.height) / 2));
	}

	// -----------------------------
	// Frame rate readout (for use during development)
	//------------------------------

	private var frameRateReadout:TextField;
	private var firstFrameTime:int;
	private var frameCount:int;

	protected function addFrameRateReadout(x:int, y:int, color:uint = 0):void {
		frameRateReadout = new TextField();
		frameRateReadout.autoSize = TextFieldAutoSize.LEFT;
		frameRateReadout.selectable = false;
		frameRateReadout.background = false;
		frameRateReadout.defaultTextFormat = new TextFormat(CSS.font, 12, color);
		frameRateReadout.x = x;
		frameRateReadout.y = y;
		addChild(frameRateReadout);
		frameRateReadout.addEventListener(Event.ENTER_FRAME, updateFrameRate);
	}

	private function updateFrameRate(e:Event):void {
		frameCount++;
		if (!frameRateReadout) return;
		var now:int = getTimer();
		var msecs:int = now - firstFrameTime;
		if (msecs > 500) {
			var fps:Number = Math.round((1000 * frameCount) / msecs);
			frameRateReadout.text = fps + ' fps (' + Math.round(msecs / frameCount) + ' msecs)';
			firstFrameTime = now;
			frameCount = 0;
		}
	}

	// TODO: Remove / no longer used
	private const frameRateGraphH:int = 150;
	private var frameRateGraph:Shape;
	private var nextFrameRateX:int;
	private var lastFrameTime:int;

	private function addFrameRateGraph():void {
		addChild(frameRateGraph = new Shape());
		frameRateGraph.y = stage.stageHeight - frameRateGraphH;
		clearFrameRateGraph();
		stage.addEventListener(Event.ENTER_FRAME, updateFrameRateGraph);
	}

	public function clearFrameRateGraph():void {
		var g:Graphics = frameRateGraph.graphics;
		g.clear();
		g.beginFill(0xFFFFFF);
		g.drawRect(0, 0, stage.stageWidth, frameRateGraphH);
		nextFrameRateX = 0;
	}

	private function updateFrameRateGraph(evt:*):void {
		var now:int = getTimer();
		var msecs:int = now - lastFrameTime;
		lastFrameTime = now;
		var c:int = 0x505050;
		if (msecs > 40) c = 0xE0E020;
		if (msecs > 50) c = 0xA02020;

		if (nextFrameRateX > stage.stageWidth) clearFrameRateGraph();
		var g:Graphics = frameRateGraph.graphics;
		g.beginFill(c);
		var barH:int = Math.min(frameRateGraphH, msecs / 2);
		g.drawRect(nextFrameRateX, frameRateGraphH - barH, 1, barH);
		nextFrameRateX++;
	}

	// -----------------------------
	// Camera Dialog
	//------------------------------

	public function openCameraDialog(savePhoto:Function):void {
		closeCameraDialog();
		cameraDialog = new CameraDialog(savePhoto);
		cameraDialog.fixLayout();
		cameraDialog.x = (stage.stageWidth - cameraDialog.width) / 2;
		cameraDialog.y = (stage.stageHeight - cameraDialog.height) / 2;
		addChild(cameraDialog);
	}

	public function closeCameraDialog():void {
		if (cameraDialog) {
			cameraDialog.closeDialog();
			cameraDialog = null;
		}
	}

	// Misc.
	public function createMediaInfo(obj:*, owningObj:ScratchObj = null):MediaInfo {
		return new MediaInfo(obj, owningObj);
	}

	static public function loadSingleFile(fileLoaded:Function, filters:Array = null):void {
		function fileSelected(event:Event):void {
			if (fileList.fileList.length > 0) {
				var file:FileReference = FileReference(fileList.fileList[0]);
				file.addEventListener(Event.COMPLETE, fileLoaded);
				file.load();
			}
		}

		var fileList:FileReferenceList = new FileReferenceList();
		fileList.addEventListener(Event.SELECT, fileSelected);
		try {
			// Ignore the exception that happens when you call browse() with the file browser open
			fileList.browse(filters);
		} catch(e:*) {}
	}

	// -----------------------------
	// External Interface abstraction
	//------------------------------

	public function externalInterfaceAvailable():Boolean {
		return false;
	}

	public function externalCall(functionName:String, returnValueCallback:Function = null, ...args):void {
		throw new IllegalOperationError('Must override this function.');
	}

	public function addExternalCallback(functionName:String, closure:Function):void {
		throw new IllegalOperationError('Must override this function.');
	}

	
	/********************************************************
	xuhy 设计的log日志内容
	********************************************************/
	/*编写代码过程中的调试log，因trace占用时间较多，后续可直接对其关闭*/
	public function xuhy_test_log(s:String,Level:int = 0):void
	{
		var WARRING:int = 0x01;
		var Err:int     = 0x02;
		switch(Level){
			case 0x00:
				trace("log :" + s);
				break;
			case WARRING:
				trace("WARRING:" + s);
				break;
			case Err:
				trace("Err:" + s);
				break;
			default :
				break;
		}
	}
	/***********************************************************
	//通过串口检查心跳包
	***********************************************************/
	
	public function setAutoConnect():uint
	{
		var intervalDuration:Number = 1500;  

		clearInterval(IntervalID);
		arduino.dispose();
		arduino = new ArduinoConnector();
		comStatus = 0x00;
		arduino.close();
		arduino.flush();
		var ts:Number = getTimer();
		while((getTimer()-ts) < 50)
			;
		arduino.connect(comIDTrue,115200);
		arduino.addEventListener("socketData", fncArduinoData);//串口接收事件监测，在fncArduinoData函数中处理_wh
		arduino.writeString('UART Open Success '+comIDTrue+'\n');//_wh
		IntervalID = setInterval(onTick_searchAndCheckUart, intervalDuration);
		uartDetectStatustimerStop = uartDetectStatustimerStart;
		return IntervalID;
	}
	
	
	private const uartDetectStatustimerStart:Number = 0x00;
	private var uartDetectStatustimerStop:Number  = 0x00;
	public  var  comStatus:int                    = 0x03;  				//com口的工作状态 0x00:连接正常 0x01:意外断开 0x02断开com口
	private var  notConnectArduinoCount:int       = 0x00;
	private var CFunConCir_Flag:Boolean           = false;
	
	public function onTick_searchAndCheckUart():void					//检测心跳包
	{	
		if (uartDetectStatustimerStop != uartDetectStatustimerStart)
		{
			comStatus = 0x00;
			uartDetectStatustimerStop = 0x00;
			notConnectArduinoCount = 0x00;
			if(CFunConCir_Flag == false)
			{
				CFunConCir(1);					//该部分功能占用较多时间，要保证其只执行一次
				CFunConCir_Flag = true;
			}
			app.xuhy_test_log("onTick_searchAndCheckUart com is --OK-- ,IntervalID = "+ IntervalID);
		}
		else
		{
			notConnectArduinoCount ++ ;
			if(notConnectArduinoCount == 1){
				xuhy_test_log("check heart phase 1 start");
				if(LibraryButtonDown){
					notConnectArduinoCount = 0x00;
				}
			}
			if(notConnectArduinoCount > 2)
			{		
				comStatus = 0x01;
				comTrue = false;	//该参数放置在此处，可以让USB意外断开后，在“连接菜单”下的 COMID号前的 对号 去掉
				notConnectArduinoCount = 0x00;	
				CFunConCir_Flag = false;
				arduino.writeString('UART Close '+comIDTrue+'\n');//_wh
				CFunConCir(0);
				arduino.close();
				clearInterval(IntervalID);
				readCDFlag = false;//通信丢失提示框标志清零_wh
				app.xuhy_test_log("uart disconnect unexpected comStatus = " + comStatus + "; IntervalID = " + IntervalID);
			}
		}
	}
}}
