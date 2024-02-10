# VimSE

VimSE is a general purpose 'runtime library' for Vim.

Here are some of the capabilities of the library:

  - Convenient extended Vim functions (e.g. 'AllMatchStr', which acts like 'matchstr', but
      returns _all_ matches)
  - A custom implementation of 'input', which allows asynchronous programming with
      callbacks on start, user input, and end
  - Preview popup windows, which can be used to preview lines in a buffer before they are
      actually changed, as the name suggests
  - Templates with regular expression functionality, and multi-line/inline capabilities
  - A custom test runner, with unit tests for some of the library

## How to Install

Using ``vim-plug``, utilizing VimSE is as easy as adding this to your ``.vimrc`` file:
```vimscript
call plug#begin('path-to-your-plugin-folder')
Plug 'MarcelSimader/VimSE'
call plug#end()
```

## License

VimSE is distributed under the Vim license. See the `LICENSE`
file or `:h license` inside Vim.

