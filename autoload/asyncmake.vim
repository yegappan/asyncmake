" File: asyncmake.vim
" Plugin to run make asynchronously and process the output in the background
" Author: Yegappan Lakshmanan (yegappan AT yahoo DOT com)
" Version: 1.0
" Last Modified: March 17, 2018
" =======================================================================

" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

let s:make_cmd = ''

" warnMsg
" Display a warning message
function! s:warnMsg(msg)
    echohl WarningMsg | echomsg a:msg | echohl None
endfunction

" s:MakeProcessOutput
" Make command output handler.  Process part of the make command output and
" add the output to a quickfix list.
function! s:MakeProcessOutput(qfid, channel, msg)
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
		\ 'lines' : [a:msg],
		\ 'efm' : s:make_efm})
    lcd -
endfunction

" s:MakeCloseCb
" Close callback for the make command channel. No more output is available.
function! s:MakeCloseCb(qf_id, channel)
    let job = ch_getjob(a:channel)
    if job_status(job) == 'fail'
	call s:warnMsg('Error: Job not found in make channel close callback')
	return
    endif
    let exitval = job_info(job).exitval
    let emsg = '[Make command exited with status ' . exitval . ']'

    " Add the exit status message if the quickfix list is still present
    let l = getqflist({'id' : a:qf_id})
    if has_key(l, 'id') && l.id == a:qf_id
	call setqflist([], 'a', {'id' : a:qf_id, 'lines' : [emsg]})

	" Open the quickfix list if make exited with a non-zero value
	if exitval != 0
	    let save_wid = win_getid()
	    copen
	    " Jump to the correct quickfix list
	    let cur_qfnr = getqflist({'nr' : 0}).nr
	    let tgt_qfnr = getqflist({'id' : a:qf_id, 'nr' : 0}).nr
	    if cur_qfnr != tgt_qfnr
		if tgt_qfnr > cur_qfnr
		    exe 'cnewer ' . (tgt_qfnr - cur_qfnr)
		else
		    exe 'colder ' . (cur_qfnr - tgt_qfnr)
		endif
	    endif
	    call win_gotoid(save_wid)
	endif
    endif
endfunction

" s:MakeCompleted
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

" expand_cmd_special()
" Expand special characters in the command line (:help cmdline-special)
" Leveraged from the dispatch.vim plugin
let s:flags = '<\=\%(:[p8~.htre]\|:g\=s\(.\).\{-\}\1.\{-\}\1\)*\%(:S\)\='
let s:expandable = '\\*\%(<\w\+>\|%\|#\d*\)' . s:flags
function! s:expand_cmd_special(string)
  return substitute(a:string, s:expandable, '\=s:expand(submatch(0))', 'g')
endfunction

function! s:expand(string)
  " Backslashes in 'makeprg' are escaped twice. Refer to :help 'makeprg'
  " for details. Reduce the number of backslashes by two.
  let slashes = len(matchstr(a:string, '^\%(\\\\\)*'))
  sandbox let v = repeat('\', slashes/2) . expand(a:string[slashes : -1])
  return v
endfunction

" Run a make command and process the output asynchronously.
" Only one make command can be run in the background.
function! asyncmake#AsyncMake(args)
    if s:make_cmd != ''
	call s:warnMsg("Error: A make command is already running")
	return
    endif

    let s:make_cmd = &makeprg

    " Replace $* (if present) in 'makeprg' with the supplied arguments
    if match(s:make_cmd, '\$\*') != -1
	let s:make_cmd = substitute(s:make_cmd, '\$\*', a:args, 'g')
    else
	if a:args != ''
	    let s:make_cmd = s:make_cmd . ' ' . a:args
	endif
    endif

    " Replace cmdline-special characters
    let s:make_cmd = s:expand_cmd_special(s:make_cmd)

    " Save all the modified buffers if 'autowrite' or 'autowriteall' is set
    if &autowrite || &autowriteall
	silent! wall
    endif

    " Create a new quickfix list at the end of the stack
    call setqflist([], ' ', {'nr' : '$',
		\ 'title' : s:make_cmd,
		\ 'lines' : ['Make command (' . s:make_cmd . ') output']})
    let qfid = getqflist({'nr':'$', 'id':0}).id

    let s:make_job = job_start(['/bin/sh', '-c', s:make_cmd], {
		\ 'callback' : function('s:MakeProcessOutput', [qfid]),
		\ 'close_cb' : function('s:MakeCloseCb', [qfid]),
		\ 'exit_cb' : function('s:MakeCompleted'),
		\ 'in_io' : 'null'})
    if job_status(s:make_job) == "fail"
        call s:warnMsg('Error: Failed to run (' . s:make_cmd . ')')
	let s:make_cmd = ''
        return
    endif
    let s:make_dir = getcwd()
    let s:make_efm = &efm
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
