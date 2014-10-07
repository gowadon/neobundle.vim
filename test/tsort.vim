let s:suite = themis#suite('tsort')
let s:assert = themis#helper('assert')

let g:path = expand('~/test-bundle')

function! s:comp_bundle(bundle1, bundle2)
  return a:bundle1.name > a:bundle2.name
endfunction

function! s:rotate_bundle(bundles)
  return a:bundles[1:-1]+a:bundles[0:0]
endfunction

function! s:suite.before_each()
  call neobundle#begin(g:path)
endfunction

function! s:suite.after_each()
  call neobundle#end()
endfunction

function! s:suite.no_depends()
  " [a, b, c] => [a, b, c]
  let neobundle_test_data = [{'name' : 'a'}, {'name' : 'b'}, {'name' : 'c'},]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ neobundle_test_data)
endfunction

function! s:suite.normal()
    " a -> b -> c
    " b -> d
    " c
    " [a, b, c] => [c, b, a]
    let neobundle_test_data = [
    \   {'name' : 'a', 'depends' : [
    \     {'name' : 'b', 'depends' : [
    \       {'name' : 'c'},
    \     ]},
    \   ]},
    \   {'name' : 'b', 'skip' : 1, 'depends' : [
    \       {'name' : 'd', 'skipped' : 1, },
    \   ]},
    \   {'name' : 'c', 'skip' : 1},
    \ ]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data), [
    \   neobundle_test_data[0].depends[0].depends[0],
    \   neobundle_test_data[0].depends[0],
    \   neobundle_test_data[0],
    \ ])

  " a -> c -> b
  " a -> d
  " b
  " c
  " [a, b, c] => [b, c, d, a]
  let neobundle_test_data = [
        \   {'name' : 'a', 'depends' : [
        \     {'name' : 'c', 'depends' : [
        \       {'name' : 'b'},
        \     ]},
        \     {'name' : 'd'},
        \   ]},
        \   {'name' : 'b', 'skip' : 1},
        \   {'name' : 'c', 'skip' : 1},
        \ ]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ [
        \   neobundle_test_data[0].depends[0].depends[0],
        \   neobundle_test_data[0].depends[0],
        \   neobundle_test_data[0].depends[1],
        \   neobundle_test_data[0],
        \ ])
endfunction

function! s:suite.tsort_circular_reference()
  " a -> b -> c -> a
  " b
  " c
  " [a, b, c] => [c, b, a]
  let neobundle_test_data = [
        \   {'name' : 'a', 'depends' : [
        \     {'name' : 'b', 'depends' : [
        \       {'name' : 'c', 'depends' : [
        \         {'name' : 'a', 'skip' : 1},
        \       ]},
        \     ]},
        \   ]},
        \   {'name' : 'b', 'skip' : 1},
        \   {'name' : 'c', 'skip' : 1},
        \ ]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ [
        \   neobundle_test_data[0].depends[0].depends[0],
        \   neobundle_test_data[0].depends[0],
        \   neobundle_test_data[0],
        \ ])
endfunction

function! s:suite.bundled_no_depends()
  NeoBundleLazy 'a/a'
  NeoBundleLazy 'b/b'
  NeoBundleLazy 'c/c'
  let neobundle_test_data = sort(filter(neobundle#config#get_neobundles(),
        \ "v:val.name =~# '^[abc]$'"), "s:comp_bundle")

  " [a, b, c] => [a, b, c]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ neobundle_test_data)

  " [c, b, a] => [c, b, a]
  call reverse(neobundle_test_data)
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ neobundle_test_data)
endfunction

function! s:suite.bundled_normal()
  NeoBundleLazy 'a/a'
  NeoBundleLazy 'b/b', {'depends' : 'a/a'}
  NeoBundleLazy 'c/c', {'depends' : 'b/b'}
  let neobundle_test_data = sort(filter(neobundle#config#get_neobundles(),
        \ "v:val.name =~# '^[abc]$'"), "s:comp_bundle")

  " [a, b, c] => [a, b, c]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ neobundle_test_data)

  " [c, b, a] => [a, b, c]
  call s:assert.equals(neobundle#config#tsort(
        \ reverse(copy(neobundle_test_data))), neobundle_test_data)
endfunction

function! s:suite.bundled_normal2()
  NeoBundleLazy 'a/a', {'depends' : ['c/c', 'b/b']}
  NeoBundleLazy 'b/b'
  NeoBundleLazy 'c/c', {'depends' : 'b/b'}
  let neobundle_test_data = sort(filter(neobundle#config#get_neobundles(),
        \ "v:val.name =~# '^[abc]$'"), "s:comp_bundle")
  let neobundle_test_rotated = s:rotate_bundle(neobundle_test_data)

  " [a, b, c] => [b, c, a]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ neobundle_test_rotated)

  " [c, b, a] => [b, c, a]
  call s:assert.equals(neobundle#config#tsort(
        \ reverse(copy(neobundle_test_data))), neobundle_test_rotated)
endfunction

function! s:suite.bundled_circular_reference()
  NeoBundleLazy 'a/a', {'depends' : 'b/b'}
  NeoBundleLazy 'b/b', {'depends' : 'c/c'}
  NeoBundleLazy 'c/c', {'depends' : 'a/a'}
  let neobundle_test_data = sort(filter(neobundle#config#get_neobundles(),
        \ "v:val.name =~# '^[abc]$'"), "s:comp_bundle")

  " [a, b, c] => [c, b, a]
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ reverse(copy(neobundle_test_data)))

  " [c, b, a] => [b, a, c]
  call reverse(neobundle_test_data)
  let neobundle_test_rotated = s:rotate_bundle(neobundle_test_data)
  call s:assert.equals(neobundle#config#tsort(neobundle_test_data),
        \ neobundle_test_rotated)
endfunction

