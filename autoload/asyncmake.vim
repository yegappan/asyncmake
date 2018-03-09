" File: asyncmake.vim
" Plugin to run make asynchronously and process the output in the background
" Author: Yegappan Lakshmanan (yegappan AT yahoo DOT com)
" Version: 1.0
" Last Modified: March 9, 2018
" =======================================================================

" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

let s:make_cmd = ''

" Make command output handler.  Process part of the make command output and
" add the output to a quickfix list.
function! s:ProcessMakeOutput(qfid, channel, msg)
    " Make sure the quickfix list is still present
    let l = getqflist({'id' : a:qfid})
    if l.id != a:qfid
	echomsg "Quickfix list not found, stopping the make"
	call job_stop(ch_getjob(a:channel))
	return
    endif

    " The user or some other plugin might have changed the directory,
    " change to the original direcotry of the make command.
    exe 'lcd ' . s:make_dir
    call setqflist([], 'a', {'id':a:qfid,
		\ 'lines' : split(a:msg, "\n"),
		\ 'efm' : s:make_efm})
    lcd -
endfunction

" Make command completion handler
function! s:MakeCompleted(job, exitStatus)
    echomsg "Make (" . s:make_cmd . ") completed"
    let s:make_cmd = ''
endfunction

" Stop a make command if it is running
function! asyncmake#CancelMake()
    if s:make_cmd == ''
	echo "Make is not running"
	return
    endif

    call job_stop(s:make_job)
    echomsg "Make command (" . s:make_cmd . ") is stopped"
endfunction

function! asyncmake#ShowMake()
    if s:make_cmd == ''
	echo "Make is not running"
	return
    endif
    echo "Make command (" . s:make_cmd . ") is running"
endfunction

" Run a make command and process the output asynchronously.
" Only one make command can be run in the background.
function! asyncmake#AsyncMake(args)
    if s:make_cmd != ''
	echomsg "Error: A make command is already running"
	return
    endif

    let s:make_cmd = &makeprg

    if a:args != ''
	let s:make_cmd = s:make_cmd . ' ' . a:args
    endif

    " Create a new quickfix list at the end of the stack
    call setqflist([], ' ', {'nr' : '$',
		\ 'title' : s:make_cmd,
		\ 'lines' : ['Make command (' . s:make_cmd . ') output']})
    let qfid = getqflist({'nr':'$', 'id':0}).id

    let s:make_job = job_start(s:make_cmd, {'out_mode' : 'raw',
		\ 'callback' : function("s:ProcessMakeOutput", [qfid]),
		\ 'exit_cb' : function("s:MakeCompleted")})
    if job_status(s:make_job) == "fail"
        echo 'Error: Failed to run (' . s:make_cmd . ')'
	let s:make_cmd = ''
        return
    endif
    let s:make_dir = getcwd()
    let s:make_efm = &efm
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
