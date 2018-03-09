" Plugin to run make asynchronously and process the output in the background
"
if exists("loaded_asyncmake")
    finish
endif
let loaded_asyncmake = 1

" Requires Vim 8.0 and above
" Patch 1040 adds support for quickfix list identifier. This feature is needed
" to use this plugin.
if v:version < 800 || !has("patch-8.0.1040")
    finish
endif

command! -nargs=* -complete=file AsyncMake call asyncmake#AsyncMake(<q-args>)
command! AsyncMakeShow call asyncmake#ShowMake()
command! AsyncMakeStop call asyncmake#CancelMake(<args>)
