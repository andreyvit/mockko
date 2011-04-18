
jQuery ($) ->
  determineAccountTypeByEmail = (email, callback) ->
    setTimeout(->
      if email.indexOf('@gmail.com') >= 0
        callback null, isNew: no, loginMethod: 'google'
      else if email.indexOf('d') >= 0
        callback null, isNew: yes, loginMethod: 'password'
      else if email.indexOf('e') >= 0
        callback "Cannot connect to the server. Please try again later!"
      else
        callback null, isNew: yes
    , 500)

  showRelevantLoginGroup = ->
    email = $('#email').val()

    $('#email-spinner').addClass('visible')
    determineAccountTypeByEmail email, (err, data) ->
      $('#email-spinner').removeClass('visible')

      logInOrSignUp = null
      if err
        groupId = '#error-group'
        $('#error-message').text(err.toString())
      else
        if email.indexOf('@') >= 0 && email.substr(email.indexOf('@') + 1).indexOf(".") >= 0
          if data['isNew']
            logInOrSignUp = 'sign-up'
            groupId = '#new-account-group'
          else
            logInOrSignUp = 'log-in'
            switch data['loginMethod']
              when 'google'
                groupId = '#existing-account-via-google-group'
              when 'password'
                groupId = '#existing-account-with-password-group'
        else
          logInOrSignUp = null

      unless $(groupId).is(':visible')
        $('.login-group').removeClass('visible')
        $(groupId).addClass('visible')

      if logInOrSignUp
        $('.login-box h1 .el').removeClass('active')
        $(".login-box h1 .#{logInOrSignUp}-el").addClass('active')
      else
        $('.login-box h1 .el').addClass('active')

  emailDidChangeTimer = null
  emailDidChange = ->
    clearTimeout(emailDidChangeTimer) if emailDidChangeTimer
    emailDidChangeTimer = setTimeout(showRelevantLoginGroup, 500)

  $('#email')
    .focus()
    .change(emailDidChange)
    .keydown(emailDidChange)
    .keypress(emailDidChange)
  showRelevantLoginGroup()
