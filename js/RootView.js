// Overload App.RootView to add additional hooks
App.RootView = App.RootView.extend({
   init : function() {
      var self = this;

      // DEPRECATED. Use jelly_pre_rootview_init instead.
      $(top).trigger('jelly.PreRootViewInit');
      $(top).trigger('jelly_pre_rootview_init', self);
      self._super();
      // DEPRECATED. Use jelly_post_rootview_init instead.
      $(top).trigger('jelly.PostRootViewInit');
      $(top).trigger('jelly_post_rootview_init', self);
   }
});