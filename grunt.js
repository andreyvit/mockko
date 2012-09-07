module.exports = function(grunt) {

  grunt.loadNpmTasks('grunt-less');
  grunt.loadNpmTasks('grunt-coffee');

  // Project configuration.
  grunt.initConfig({

    meta: {
      COFFEE_SRC: ['web/static/*.coffee',
                   'web/webios/webios/*.coffee'],

//      LESS_SRC:   ['web/static/*.less',
//                   'web/static/*/*.less',
//                   'web/webios/webios/*.less'],

      HAML_SRC:   ['web/*.haml',
                   'web/static/*/*.haml',
                   'web/webios/*.haml'],

      JS_SRC:     ['web/static/geometry.js',
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

      JS_LIBS:    ['web/static/lib/jquery.min.js',
                   'web/static/lib/jquery-ui.custom.min.js',
                   'web/static/lib/underscore.min.js',
                   'web/static/lib/jquery.cookie.js'],

    },
    coffee: {
      app: {
        src: '<config:meta.COFFEE_SRC>',
        options: {
            bare: false,
            preserve_dirs: true
        }
      }
    },

//    concat: {
//      dist: {
//        src: ['<banner:meta.banner>', '<file_strip_banner:lib/<%= pkg.name %>.js>'],
//        dest: 'dist/<%= pkg.name %>.js'
//      }
//    },

    less: {
      home: {
          src: 'web/static/home.less',
          dest: 'web/static/home.css'
      },
      iphone: {
          src: 'web/static/iphone/iphone.less',
          dest: 'web/static/iphone/iphone.css'
      },
      theme_common: {
          src: 'web/static/theme/theme-common.less',
          dest: 'web/static/theme/theme-common.css'
      },
      theme_dashboard: {
          src: 'web/static/theme/theme-dashboard.less',
          dest: 'web/static/theme/theme-dashboard.css'
      },
      theme_designer: {
          src: 'web/static/theme/theme-designer.less',
          dest: 'web/static/theme/theme-designer.css'
      },
      theme_mixins: {
          src: 'web/static/theme/theme-mixins.less',
          dest: 'web/static/theme/theme-mixins.css'
      },
      webios_components: {
          src: 'web/webios/webios/webios-components.less',
          dest: 'web/webios/webios/webios-components.css'
      },
      webios_screen: {
          src: 'web/webios/webios/webios-screen.less',
          dest: 'web/webios/webios/webios-screen.css'
      }
    },

    min: {
      dist: {
        src: '<config:meta.JS_SRC>',
        dest: 'web/minified/designer.uglify.js'
      }
    },
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
