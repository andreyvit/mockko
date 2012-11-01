module.exports = function(grunt) {

  grunt.loadNpmTasks('grunt-coffee');
  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-jade');

  // Project configuration.
  grunt.initConfig({

    meta: {
      COFFEE_SRC: ['web/static/*.coffee',
                   'web/webios/webios/*.coffee'],

//      LESS_SRC:   ['web/static/*.less',
//                   'web/static/*/*.less',
//                   'web/webios/webios/*.less'],

      JADE_SRC:   ['web/*.jade',
                   'web/static/*/*.jade',
                   'web/webios/*.jade'],

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
        files: {
          'web/static/home.css': 'web/static/home.less'
        }
      },
      iphone: {
        files: {
          'web/static/iphone/iphone.css': 'web/static/iphone/iphone.less'
        }
      },
      theme: {
        files: {
          'web/static/theme/theme-common.css': 'web/static/theme/theme-common.less',
          'web/static/theme/theme-dashboard.css': 'web/static/theme/theme-dashboard.less',
          'web/static/theme/theme-designer.css': 'web/static/theme/theme-designer.less',
          'web/static/theme/theme-mixins.css': 'web/static/theme/theme-mixins.less',
        }
      },
      webios: {
        files: {
          'web/webios/webios/webios-components.css': 'web/webios/webios/webios-components.less',
          'web/webios/webios/webios-screen.css': 'web/webios/webios/webios-screen.less',
        }
      }
    },

    jade: {
      designer: {
        src: "web/designer.jade",
        dest: "web/",
        options: {
          client: false,
          pretty: true
        }
      },
      home: {
        src: "web/home.jade",
        dest: "web/",
        options: {
          client: false,
          pretty: true
        }
      },
      webios_demo: {
        src: "web/webios/demo.jade",
        dest: "web/webios",
        options: {
          client: false,
          pretty: true
        }
      }
    },

    min: {
      designer: {
        src: '<config:meta.JS_SRC>',
        dest: 'web/minified/designer.uglify.js'
      }
    },

    concat: {
      dist: {
        //src: ['<config:meta.JS_LIBS>', 'web/minified/designer.uglify.js'],
        src: ['<config:meta.JS_LIBS>', '<config:meta.JS_SRC>'],
        dest: 'web/minified/designer.min.js'
      }
    }

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
