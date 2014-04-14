Datastore = require('nedb')
async = require('async')
_ = require('underscore')

config = require('./config')
database = require('./database')
pocket = require('./pocket')

class Worker

	constructor: () ->

		that = @
		that.db = config.db

		_.each that.db, (dbObj, dbName) ->
			that.db[dbName] = new Datastore({filename: './db/' + dbName + '.db'})
			that.db[dbName].loadDatabase()

	compactDB: () ->

		that = @
		that.db = config.db

		_.each that.db, (dbObj) ->
			dbObj.persistence.compactDatafile()

	listArticle: (callback) ->

		that = @

		async.waterfall [

			(callback) ->
				database.listUser (err, results) ->
					console.log(results)
					callback(err, results)

			, (results, callback) ->

				listFunc = []

				_.each results, (result) ->
					accessToken = result.access_token
					listFunc.push((callback) ->
						pocket.request.listArticle accessToken, (dataObj) ->
							callback(null, dataObj)
					)

				async.parallel listFunc, (err, results) ->
					callback(results)

		], (err, result) ->
			console.log(err)

worker = new Worker()

(dbCompactLoop = () ->
	setTimeout () ->
		worker.compactDB()
		dbCompactLoop()
	, 2000
)()

(listArticleLoop = () ->
	setTimeout () ->
		worker.listArticle((results) ->
			console.log(results)
		)
		listArticleLoop()
	, 2000
)()

# process.on 'message', (msg) ->
# 	console.log('child: ', msg)

# process.send({foo: 'bar'})