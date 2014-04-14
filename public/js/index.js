$(function() {
	
	$(document).on('click', '.circle-join', function(event) {

		var $joinBtn = $(event.currentTarget);
		var $circleItem = $joinBtn.parents('.circle-item');
		var circleTag = $circleItem.data('tag');
		var circleState = $circleItem.data('state');

		if (circleState === 'joined') {

			$joinBtn.text('退出中...');
			$.post('/quitCircle', {
				circle_tag: circleTag
			}, function(data, status, xhr) {

				if (data.success) {
					location.reload();
				} else {
					$joinBtn.text('跳转授权...');
					var authURL = data.data;
					location.href = authURL;
				}

			}, 'json');

		} else {

			$joinBtn.text('加入中...');
			$.post('/joinCircle', {
				circle_tag: circleTag
			}, function(data, status, xhr) {

				if (data.success) {
					location.reload();
				} else {
					$joinBtn.text('跳转授权...');
					var authURL = data.data;
					location.href = authURL;
				}

			}, 'json');

		}

	});

});