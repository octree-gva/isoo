import * as esbuild from 'esbuild'

await esbuild.build({
  entryPoints: ['assets/js/markdown-editor.js'],
  bundle: true,
  format: 'iife',
  globalName: 'IsooMarkdownEditor',
  outfile: 'public/js/markdown-editor.js',
  minify: true,
  legalComments: 'none',
})
