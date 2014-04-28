express = require('express')
consolidate = require('consolidate')

model = require('./model')
config = require('./config')

app = express()
app.use(express.json())
app.use(express.urlencoded())
app.use(express.cookieParser())
app.use(express.cookieSession({secret: 'team_push'}))

app.use(express.static(__dirname + '/public'))
app.engine('html', consolidate.handlebars)
app.set('view engine', 'html')
app.set('views', __dirname + '/views')

app.get '/callback', model.getAccessToken
app.get '/auth', model.getReqToken
app.get '/', model.indexPage
app.get '/info/:accessToken', model.infoPage
app.get '/help', model.helpPage

app.post '/joinCircle', model.joinCircle
app.post '/quitCircle', model.quitCircle

app.listen(config.server_port)


