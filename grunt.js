module.exports = function(grunt) {

//  grunt.loadNpmTasks('grunt-less');

  // Project configuration.
  grunt.initConfig({

//    pkg: '<json:package.json>',
    meta: {
      JS_SRC: ['web/static/geometry.js',
               'web/static/designer-jqueryaddons.js',
               'web/static/designer-components.js',
               'web/static/designer-templates.js',
               'web/static/designer-online.js',
               'web/static/designer-offline.js',
               'web/static/designer-actions.js',
               'web/static/designer-serialization.js',
               'web/static/designer-rendering.js',
               'web/static/designer-undo.js',
               'web/static/designer-model.js',
               'web/static/designer-alignment-detection.js',
               'web/static/designer-stacking-legacy.js',
               'web/static/designer-hover-panel.js',
               'web/static/designer-snapping.js',
               'web/static/designer-layouting.js',
               'web/static/designer-component-tree.js',
               'web/static/designer-effect-live-applicator.js',
               'web/static/designer-dragging.js',
               'web/static/designer-resizing.js',
               'web/static/designer-inspector.js',
               'web/static/jpicker.js',
               'web/static/designer.js'],

//      LESS_SRC:   ['web/static/*.less',
//               'web/static/*/*.less'
//               'web/webios/webios/*.less']

//      banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' +
//        '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
//        '<%= pkg.homepage ? "* " + pkg.homepage + "\n" : "" %>' +
//        '* Copyright (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %>;' +
//        ' Licensed <%= _.pluck(pkg.licenses, "type").join(", ") %> */'
    },
//    concat: {
//      dist: {
//        src: ['<banner:meta.banner>', '<file_strip_banner:lib/<%= pkg.name %>.js>'],
//        dest: 'dist/<%= pkg.name %>.js'
//      }
//    },

//    less: {
//      homepage: {
//        src: '<config:meta.LESS>',
//        dest: 'homepage.css',
//        options: {
//          yuicompress: true
//          compress: true
//        }
//      }
//    }

    min: {
      dist: {
        src: '<config:meta.JS_SRC>',
        dest: 'web/minified/designer.uglify.js'
      }
    },
//    test: {
//      files: ['test/**/*.js']
//    },
//    lint: {
//      files: ['grunt.js', 'lib/**/*.js', 'test/**/*.js']
//    },
//    watch: {
//      files: '<config:lint.files>',
//      tasks: 'lint test'
//    },
//    jshint: {
//      options: {
//        curly: true,
//        eqeqeq: true,
//        immed: true,
//        latedef: true,
//        newcap: true,
//        noarg: true,
//        sub: true,
//        undef: true,
//        boss: true,
//        eqnull: true
//      },
//      globals: {
//        exports: true,
//        module: false
//      }
//    },
//    uglify: {}
  });

  // Default task.
  grunt.registerTask('default', 'min');

};
