" File: asyncmake.vim
" Plugin to run make asynchronously and process the output in the background
" Author: Yegappan Lakshmanan (yegappan AT yahoo DOT com)
" Version: 1.0
" Last Modified: March 9, 2018
" =======================================================================

if exists("loaded_asyncmake")
    finish
endif
let loaded_asyncmake = 1

" Line continuation used here
let s:cpo_save = &cpo
set cpo&vim

" Requires Vim 8.0 and above
" Patch 1040 adds support for quickfix list identifier. This feature is needed
" to use this plugin.
if v:version < 800 || !has("patch-8.0.1040")
    finish
endif

command! -nargs=* -complete=file AsyncMake call asyncmake#AsyncMake(<q-args>)
command! AsyncMakeShow call asyncmake#ShowMake()
command! AsyncMakeStop call asyncmake#CancelMake(<args>)

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
