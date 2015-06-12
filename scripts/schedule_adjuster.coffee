randomstring = require 'randomstring'

module.exports = (robot) ->
  robot.respond /(adjust schedule from|as) (.*)/, (res) ->
    code = randomstring.generate(5)
    candidates = res.match[2].split /,|and/

    for value, i in candidates
      candidates[i] = value.trim()

    name = robot.name
    room = res.message.room

    robot.brain.set("as_#{room}_#{code}", candidates)
    robot.brain.set("as_last_#{room}", code)

    res.reply "OK, I'd like to do it. Code = #{code}, Candidate = #{candidates.join(', ')}"
    res.send """
@channel, please talk to me like
`@#{name}, I'm available #{candidates[0]}, ... (about #{code})`,
`@#{name}, Maybe I'm available #{candidates[0]}, ... (about #{code})` or
`@#{name}, I'm not available #{candidates[0]}, .. (about #{code})` (when you want to cancel)
"""

  robot.respond /tell me last code/, (res) ->
    room = res.message.room
    code = robot.brain.get("as_last_#{room}")
    return res.reply 'No data.. :(' unless code

    candidates = robot.brain.get("as_#{room}_#{code}")
    res.reply "Code = #{code}, Candidates = #{candidates.join(', ')}"


  userVote = (room, code, name, answer, value) ->
    candidates = robot.brain.get("as_#{room}_#{code}")
    vote = robot.brain.get("asv_#{room}_#{code}")

    if (!vote)
      vote = {}
      for candidate in candidates
        vote[candidate] = {}

    if vote[answer] != undefined
      vote[answer][name] = value

    robot.brain.set("asv_#{room}_#{code}", vote)

    vote

  getUsersStatus = (users) ->
    result = []
    for user, value of users
      if value == 1
        result.push user
      else if value == 0.5
        result.push "(#{user})"

    result.join ","

  getVoteStatus = (vote) ->
    result = []
    for candidate, users of vote
      totalPoint = 0
      for user, point of users
        totalPoint += point

      result.push "#{candidate}(#{totalPoint}): #{getUsersStatus(users)}"

    result.join "\n"

  processVote = (res, value) ->
    room = res.message.room

    code = res.match[3]
    code = robot.brain.get("as_last_#{room}") unless code
    return res.reply 'No data.. :(' unless code

    votes = userVote(room, code, res.envelope.user.name, res.match[1].split(/,|and/), value)

    res.reply "Thank you for your comment:\n#{getVoteStatus(votes)}"

  robot.respond /I'm available (.+)( +about +)?(.{5})?/, (res) ->
    processVote(res, 1)

  robot.respond /Maybe I'm available (.+)( +about +)?(.{5})?/, (res) ->
    processVote(res, 0.5)

  robot.respond /I'm not available (.+)( +about +)?(.{5})?/, (res) ->
    processVote(res, 0)
