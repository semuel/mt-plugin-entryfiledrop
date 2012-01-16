package EntryFileDrop;
use strict;
use warnings;

my $DropJS = <<'JSEND';

  var $asset_f = jQuery('#assets-field');
  $asset_f.css('z-index', 10);
  var now = new Date();
  var dateStr = now.getFullYear() + "/";
  if (now.getMonth() < 9 ) dateStr += "0";
  dateStr += (now.getMonth() + 1).toString() + "/"; 
  if (now.getDate() < 10 ) dateStr += "0";
  dateStr += now.getDate(); 

  jQuery('<div></div>')
  	.attr('id', 'asset_xhr_upload_status')
  	.css('display', 'none')
  	.insertAfter($asset_f.find('#asset-list'));

  jQuery('<div></div>')
  	.addClass('droppable-cover')
  	.css({'z-index': 50, 'position': 'absolute', 'display': 'none', 'background-color': '#DCDDDD'})
  	.html('<h2><__trans phrase="Drop the files here!"></h2>')
  	.appendTo($asset_f);

  function insertAsset(id, name, type, thumbnail) {
    var $list = $asset_f.find('#asset-list');
    $list.find('#empty-asset-list').remove();
    if ($list.find('#list-asset-' + id).length) {
      return // this asset already exists
    }
    var $id_list = $asset_f.find('#include_asset_ids');
    var asset_ids = $id_list.val();
    if (asset_ids.length > 0) {
      asset_ids += ',';
    }
    $id_list.val( asset_ids + id );
    var $item = jQuery('<li></li>')
      .attr('id', 'list-asset-'+id)
      .addClass('asset-type-'+type);
    jQuery('<a></a>')
      .attr('href', '<mt:CGIPath><mt:AdminScript>?__mode=view&_type=asset&blog_id=<mt:var name="blog_id" escape="url">&id='+id)
      .addClass('asset-title')
      .text(name)
      .appendTo($item);
    jQuery('<a></a>')
      .attr('href', 'javascript:removeAssetFromList('+id+')')
      .attr('title', '<__trans phrase="Remove this asset.">')
      .addClass('remove-asset icon-remove icon16 action-icon')
      .text('<__trans phrase="Remove">')
      .appendTo($item);
    if (( type === 'image') && (thumbnail)) {
      $item
        .mouseover( function () { show('list-image-'+id)} )
        .mouseout(  function () { hide('list-image-'+id)} );
      jQuery('<img><img>')
        .attr({ 'id': 'list-image-'+id, 'src': thumbnail })
        .addClass('list-image hidden')
        .appendTo($item);
    }
    $item.appendTo($list);
  }

  jQuery('#assets-field').filedrop({
      maxfiles: 25,
      maxfilesize: 20,    // max file size in MBs
      url: '<mt:var name="script_url">', // upload handler, handles each file separately
      paramname: 'file',          // POST parameter name used on serverside to reference file
      data: {
          // send POST variables
          __mode: 'upload_asset_xhr',
          blog_id: <mt:var name="blog_id" escape="url">,
          magic_token: '<mt:var name="magic_token">',
          middle_path: dateStr
      },
      docOver: function() {
          // user dragging files anywhere inside the browser document window
          var ppos = $asset_f.offset();
          $asset_f.find('div.droppable-cover')
            .css('top', ppos.top).css('left', ppos.left)
            .height($asset_f.height()).width($asset_f.width())
            .show();
      },
      docLeave: function() {
          // user dragging files out of the browser document window
          $asset_f.find('div.droppable-cover').hide();
      },
      drop: function() {
          // user drops file
          $asset_f.find('div.droppable-cover').hide();
      },
      uploadStarted: function(i, file, len){
          // a file began uploading
          // i = index => 0, 1, 2, 3, 4 etc
          // file is the actual file of the index
          // len = total files user dropped
          $asset_f.find('#asset_xhr_upload_status')
            .html('Uploading ' + (i+1) + '/' + len + ': ' + file.name)
            .show();
      },
      error: function(err, file) {
        alert(err);
      },
      uploadFinished: function(i, file, response, time) {
          // response is the data you got back from server in JSON format.
          $asset_f.find('#asset_xhr_upload_status').hide();
          var result = response.result.type;
          if (result === 'success') {
            var res = response.result;
            insertAsset(res.asset_id, file.name, res.asset_type, res.thumbnail);
          }
          else if (result === 'overwrite') {
            // file with this name already exists - ask the user
            var params = response.result.params;
            var $over;

            var overfunc = function (opts, callback) {
              jQuery.post(
                '<mt:var name="script_url">',
                jQuery.extend({
                  __mode: 'upload_asset_xhr',
                  blog_id: <mt:var name="blog_id" escape="url">,
                  magic_token: '<mt:var name="magic_token">',
                  fname: params.fname,
                  temp: params.temp,
                  middle_path: dateStr
                }, opts), callback, 'json');
                $over.remove();
            };

            $over = jQuery('<div></div>')
              .css({'position': 'relative', 'overflow': 'auto'});
            var $b_div = jQuery('<div></div>')
              .css({'float': 'right', 'top': 0})
              .appendTo($over);
            jQuery('<button></button>')
              .text('Yes')
              .addClass('action button')
              .click(function () {
                overfunc( { overwrite_yes: 1 }, function (data) { 
                  var res = data.result;
                  insertAsset(res.asset_id, file.name, res.asset_type, res.thumbnail); 
                });
              })
              .appendTo($b_div);
            jQuery('<button></button>')
              .text('No')
              .addClass('action button')
              .click(function () {
                overfunc( { overwrite_no: 1 }, function (data) { });
              })
              .appendTo($b_div);
            jQuery('<div></div>').text('overwrite '+file.name+'?')
              .appendTo($over);
            $over.appendTo($asset_f.find('#asset_container'));
          }
      }
  });
JSEND

sub install_dropzone {
    my ($cb, $app, $params, $tmpl) = @_;

	my $js_include = '<script type="text/javascript" src="'
		. $app->static_path()
		. 'plugins/EntryFileDrop/jquery.filedrop.js?v='
		. $params->{mt_version_id}
		. '"></script>';
	$params->{js_include} = ($params->{js_include} || '') . $js_include;

	$DropJS =~ s/<mt:CGIPath>/$app->config('CGIPath')/ge;
	$DropJS =~ s/<mt:AdminScript>/$app->config('AdminScript')/ge;
	$DropJS =~ s/<mt:var name="script_url">/$params->{script_url}/ge;
	$DropJS =~ s/<mt:var name="blog_id" escape="url">/$params->{blog_id}/ge;
	$DropJS =~ s/<mt:var name="magic_token">/$params->{magic_token}/ge;
	$params->{jq_js_include} = ($params->{jq_js_include} || '') . $DropJS;
}

sub upload_asset_xhr {
    my $app = shift;

    my $blog = $app->blog
        or return $app->json_error( $app->translate("Invalid request.") );

    my $perms = $app->permissions
        or return $app->json_error( $app->translate("Permission denied.") );

    return $app->json_error( $app->translate("Permission denied.") )
        unless $perms->can_do('upload');

    $app->validate_magic() or return;

    # workaround so they won't return empty lists inside _upload_file
    $app->param('asset_select', ($app->param('asset_select') || ''));
    $app->param('entry_insert', ($app->param('entry_insert') || ''));
    $app->param('edit_field',   ($app->param('edit_field')   || ''));

    require MT::CMS::Asset;
    
    my ( $asset, $bytes ) = MT::CMS::Asset::_upload_file(
        $app,
        require_type => ( $app->param('require_type') || '' ),
        @_,
    );

    return $app->json_error( $app->translate("Error uploading file") )
        unless $asset;
    
    if (not $bytes) {
        # this is an overwrite - we need to ask the user
        # $asset actually contain a template object
        my $tmpl_params = $asset->param();
        my $params = {};
        foreach my $key (qw{ temp fname }) {
            $params->{$key} = $tmpl_params->{$key};
        }
        return $app->json_result(
            {   type   => 'overwrite',
                params => $params,
            }
        );
    }

    my $class = $asset->class();
    my %params;
    if ($class eq 'image') {
        my ($t_url) = $asset->thumbnail_url(Blog => $blog, Width => 100);
        $params{thumbnail} = $t_url;
    }

    return $app->json_result(
        {   type   => 'success',
            asset_id => $asset->id(),
            asset_type => $class,
            %params,
        }
    );

}
