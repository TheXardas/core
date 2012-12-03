define [
  'moment'
  'cord!isBrowser'
], (moment, isBrowser) ->

  if isBrowser
    momentru = require ['moment-ru'], (ru) =>
      moment.lang 'ru'
  else
    moment.lang 'ru'

  class Utils

    @parseArguments: (args, map) ->
      stringArgument = ''
      objectArgument = {}
      functionArgument = null

      for argument in args
        stringArgument = argument if typeof argument == 'string'
        objectArgument = argument if typeof argument == 'object'
        functionArgument = argument if typeof argument == 'function'

      for key, type of map
        map[key] = stringArgument if type == 'string'
        map[key] = objectArgument if type == 'object'
        map[key] = functionArgument if type == 'function'

      map

    @morphology = (number, n0, n1, n2) ->
      number = number % 100
      number = number % 10 if number > 19

      return n2 if number >= 2 and number <= 4
      return n1 if number == 1
      return n0

    @monthFormat = (month) ->
      months =
        0:  'января'
        1:  'февраля'
        2:  'марта'
        3:  'апреля'
        4:  'мая'
        5:  'июня'
        6:  'июля'
        7:  'августа'
        8:  'сентября'
        9:  'октября'
        10: 'ноября'
        11: 'декабря'
      months[month]

    @dateFormat = (text, format = 'simple') ->
      return '' if !text

      if text == 'now'
        date = moment()
      else
        date = moment(text, 'YYYY-MM-DD HH:mm:ss')

      # в идеале написать date.calendar()
      # дока http://momentjs.com/docs/

      date = date.toDate()
      now = new Date()

      daysDiff = (now - date) / (1000 * 60 * 60 * 24)

      detailed = format == 'detailed'
      time = date.getHours() + ':' + date.getMinutes()

      ## Сегодня
      if date.getDate() == now.getDate() and date.getMonth() == now.getMonth() and date.getYear() == now.getYear()
        if detailed
          return 'сегодня в ' + time
        else
          return 'сегодня'
      ## Вчера
      else if daysDiff < 1 and daysDiff >= 0
        return 'вчера в ' + time
      ## Завтра
      else if daysDiff > -1 and daysDiff <= 0
        return 'завтра в ' + time
      else
        ## но в этом году
        if date.getYear() == now.getYear()
          if detailed
            return date.getDate() + ' ' + Utils.monthFormat(date.getMonth()) + ' в ' + time
          else
            return date.getDate() + ' ' + Utils.monthFormat(date.getMonth())
        else
          return date.getDate() + ' ' + Utils.monthFormat(date.getMonth()) + ' ' + date.getFullYear()


    @dateDiffInDays = (date) ->
      today = new Date()
      date = new Date date

      seconds = ( date - today ) / 1000
      seconds / ( 60 * 60 * 24 )


    @getAgeByBirthday = (date) ->
      today = new Date()
      birthDate = new Date(date)
      years = today.getFullYear() - birthDate.getFullYear()
      months = today.getMonth() - birthDate.getMonth()
      if (months < 0) or (months == 0 and today.getDate() < birthDate.getDate())
        years--
      years


    @phoneNumberFormat = (number) ->
      if number.length == 7
        number = [
          number.substr(0,3)
          number.substr(3,2)
          number.substr(5,2)
        ].join '-'
      else if number.length == 6
        number = [
          number.substr(0,3)
          number.substr(3,3)
        ].join '-'
      number

    @stripTags = (input, allowed) ->
      ###
        A JavaScript equivalent of PHP’s strip_tags
        http://phpjs.org/functions/strip_tags/
      ###

      input = '' if not input

      allowed = (((allowed || "") + "").toLowerCase().match(/<[a-z][a-z0-9]*>/g) || []).join('')
      tags = /<\/?([a-z][a-z0-9]*)\b[^>]*>/gi
      commentsAndPhpTags = /<!--[\s\S]*?-->|<\?(?:php)?[\s\S]*?\?>/gi
      input.replace(commentsAndPhpTags, '').replace tags, ($0, $1) ->
        if allowed.indexOf('<' + $1.toLowerCase() + '>') > -1
          return $0
        else
          return '';
