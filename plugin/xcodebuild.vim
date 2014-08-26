" Description:	An easy way to use xcodebuild with Vim
" Author: Jerry Marino <@jerrymarino>
" License: Vim license
" Version .45

" Run 
" TODO integrate simulator vim plugin https://github.com/phonegap/ios-sim

" Test  
nn <leader>u :call g:XCB_Test()<cr> 

" Build current target
nn <leader>b :call g:XCB_Build()<cr> 

" Clean current target
nn <leader>K :call g:XCB_Clean()<cr> 

" Debug 
" TODO integrate debugging 

" Show Build Info
nn <leader>pi :call g:XCB_BuildInfo()<cr> 

" Show Build Command 
nn <leader>bi :call g:XCB_BuildCommandInfo()<cr> 

let s:projectName = '' 
let s:targets = []
let s:schemes = []
let s:buildConfigs = []
let s:sdk = ''
let s:buildConfiguration = ''
let s:target = ''
let s:testTarget = ''
let s:scheme = ''
let s:noProjectError = ''

fun s:init()
	let s:noProjectError = "Missing .xcodeproj, "
		\ . "run vim from your project\'s root directory."
	call g:XCB_LoadBuildInfo()
	if s:projectIsValid()	
		call s:defaultInit()
	endif
endf

fun s:projectIsValid()
	if !empty(s:projectName)
		return 1
	endif
	return 0
endf

fun s:defaultInit()
	let s:sdk = "iphonesimulator"
	let s:buildConfiguration = "Debug"
	let s:testTarget = "'". substitute(s:projectName, "\.\/", "", "") ."'" . "Tests"
  let s:target = "'". substitute(s:projectName, "\.\/", "", "") ."'"
endf
 
fun g:XCB_SetTarget(target)
	if !s:targetIsValid(a:target)
		echoerr "Invalid target, "
			\ . " use XCB_BuildInfo() to get project info" 
		return
	endif
	let s:target = a:target
	echo a:target
endf

fun s:targetIsValid(target)
	if index(s:targets, a:target) < 0  
		return 0
	endif
	return 1	
endf 

fun g:XCB_SetTestTarget(target)
	if !s:targetIsValid(a:target)
		echoerr "Invalid target, "
			\ . " use XCB_BuildInfo() to get project info" 
		return
	endif
	let s:testTarget =  a:target
endf

fun g:XCB_SetScheme(scheme)
	if !s:schemeIsValid(a:scheme)
		echoerr "Invalid scheme, "
			\ . " use XCB_BuildInfo() to get project info" 
		return
	endif
	let s:scheme = a:scheme
	echo a:scheme
endf

fun s:schemeIsValid(scheme)
	if index(s:schemes, a:scheme) < 0  
		return 0
	endif
	return 1	
endf 

" TODO allow setting of s:sdk and validate input

fun g:XCB_Test()
	if !s:projectIsValid()	
		echoerr s:noProjectError
		return
	endif
	call g:XCB_RunBuildCommand(s:buildCommandWithTarget(s:testTarget))
endf

fun s:buildCommandWithTarget(target)
	let cmd = "xcodebuild "
                \ . " -target " . a:target
        if(!empty(s:sdk))
                let cmd .= " -sdk " . s:sdk
        endif
        if(!empty(s:buildConfiguration))
                let cmd .= " -configuration " . s:buildConfiguration
        endif
        if(!empty(s:scheme))
                let cmd .= " -scheme " . s:scheme
        endif
	return cmd
endf

fun g:XCB_Build()
	if !s:projectIsValid()	
		echoerr s:noProjectError
		return
	endif
	call g:XCB_RunBuildCommand(s:buildCommandWithTarget(s:target))
endf

fun g:XCB_Clean()
	if !s:projectIsValid()	
		echoerr s:noProjectError
		return
	endif
	let cmd = "xcodebuild "
		\ . " clean "
		\ . " -target " . s:target	
	call g:XCB_RunBuildCommand(cmd)
endf

fun g:XCB_BuildCommandInfo()
	if !s:projectIsValid()	
		echoerr s:noProjectError
		return
	endif
	echo s:buildCommandWithTarget(s:target)
endf	

fun g:XCB_BuildInfo()
	if empty(s:projectName)
		echoerr s:noProjectError
		return
	endif
	echo "Targets:" . join(s:targets, ' ') 
		\ . "\tBuild Configurations:" . join(s:buildConfigs, ' ')  
		\ . "\tSchemes:" . join(s:schemes, ' ')
endf

fun g:XCB_LoadBuildInfo()
	let s:projectName = s:findProjectFileName()
	if empty(s:projectName)
		return 
	endif
	let outputList = split(system("xcodebuild -list"), '\n')
	
	let configTypeEx = '\([^ :0-9"]\([a-zA-Z ]*\)\(:\)\)'
	let typeSettingEx = '\([^ ]\w\w\+$\)'
	
	let configVarToTitleDict = {'Build Configurations:' : s:buildConfigs, 'Targets:' : s:targets, 'Schemes:' : s:schemes}
	let configVar = []
	for line in outputList 
		if match(line, configTypeEx) > 1
			let typeTitle = matchstr(line, configTypeEx)
			if has_key(configVarToTitleDict, typeTitle)  	
				let configVar = get(configVarToTitleDict, typeTitle, 'default') 
			endif
		elseif match(line, typeSettingEx) > 1 
			let typeSetting = matchstr(line, typeSettingEx)
			if strlen(typeSetting) > 1
				call add(configVar, typeSetting)
			endif
		endif
	endfor
endf

fun s:findProjectFileName()
	let s:projectFile = globpath(expand('.'), '*.xcodeproj')
	return matchstr(s:projectFile, '.*\ze.xcodeproj')
endf

fun g:XCB_RunBuildCommand(cmd)
	" Thanks to jason @ http://vios.eraserhead.net/blog/2011/09/25/driving-kiwi-with-vim/
	let l:BuildLog = "build/vim.log"
	if l:bf bufname("%") != ""
		silent write
	endif
	echo "Building.."
	let l:StartTime = reltime()
	exec "silent !" . a:cmd . " >" . l:BuildLog . " 2>&1"

	" xcodebuild does NOT set exit code properly, so check the build log
	exec "silent !grep -q '^\*\* BUILD FAILED' " . l:BuildLog
	redraw!
	if !v:shell_error
		set errorformat=
			\%f:%l:%c:{%*[^}]}:\ error:\ %m,
			\%f:%l:%c:{%*[^}]}:\ fatal\ error:\ %m,
			\%f:%l:%c:{%*[^}]}:\ warning:\ %m,
			\%f:%l:%c:\ error:\ %m,
			\%f:%l:%c:\ fatal\ error:\ %m,
			\%f:%l:%c:\ warning:\ %m,
			\%f:%l:\ Error:\ %m,
			\%f:%l:\ error:\ %m,
			\%f:%l:\ fatal\ error:\ %m,
			\%f:%l:\ warning:\ %m
		execute "cfile! " . l:BuildLog
	else
		echo "Building.. OK - " . reltimestr(reltime(l:StartTime)) . " seconds"
	endif
endf


call s:init()
