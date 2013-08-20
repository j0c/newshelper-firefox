let $ = jQuery

  containerNodes = {}
  className = \newshelper-checked


  addContainerNodes = (titleText, linkHref, containerNode) ->
    if containerNodes[linkHref]?
      containerNodes[linkHref].nodes.push(containerNode)
    else
      containerNodes[linkHref] = {nodes: [containerNode], linkHref, titleText}


  buildWarningMessage = (options) ->
    """
    <div class="newshelper-warning-facebook">
      <div class="arrow-up"></div>
      注意！您可能是<b>問題新聞</b>的受害者
      <span class="newshelper-description">
    """ + $("<span></span>").append($("<a></a>").attr(
      href: options.link
      target: "_blank"
    ).text(options.title)).html() + "</span></div>"


  censorFacebook = (baseNode) ->
    # add warning message to a Facebook post if necessary
    censorFacebookNode = (containerNode, titleText, linkHref) ->
      matches = ("" + linkHref).match("^http://www.facebook.com/l.php\\?u=([^&]*)")
      linkHref = decodeURIComponent(matches[1])  if matches
      containerNode = $(containerNode)
      if containerNode.hasClass(className)
        return

      # 先看看是不是 uiStreamActionFooter, 表示是同一個新聞有多人分享, 那只要最上面加上就好了
      addedAction = false
      containerNode.parent("div[role=article]").find(".uiStreamActionFooter").each (idx, uiStreamSource) ->
        $(uiStreamSource).find("li:first").append "· " + buildActionBar(
          title: titleText
          link: linkHref
        )
        addedAction = true


      # 再看看單一動態，要加在 .uiStreamSource
      unless addedAction
        containerNode.parent("div[role=article]").find(".uiStreamSource").each (idx, uiStreamSource) ->
          $($("<span></span>").html(buildActionBar(
            title: titleText
            link: linkHref
          ))).insertBefore uiStreamSource

          # should only have one uiStreamSource
          console.error idx + titleText  unless idx is 0

      addContainerNodes titleText, linkHref, containerNode

      self.port.emit \logBrowsedLink, {linkHref, titleText}
      self.port.emit \checkReport, {linkHref, titleText}


    # my timeline
    $(baseNode).find(".uiStreamAttachments").each (idx, uiStreamAttachment) ->
      uiStreamAttachment = $(uiStreamAttachment)
      unless uiStreamAttachment.hasClass("newshelper-checked")
        titleText = uiStreamAttachment.find(".uiAttachmentTitle").text()
        linkHref = uiStreamAttachment.find("a").attr("href")
        censorFacebookNode uiStreamAttachment, titleText, linkHref


    # others' timeline, fan page
    $(baseNode).find(".shareUnit").each (idx, shareUnit) ->
      shareUnit = $(shareUnit)
      unless shareUnit.hasClass("newshelper-checked")
        titleText = shareUnit.find(".fwb").text()
        linkHref = shareUnit.find("a").attr("href")
        censorFacebookNode shareUnit, titleText, linkHref


    # post page (single post)
    $ baseNode .find \._6kv .not \newshelper-checked .each (idx, userContent) ->
      userContent = $(userContent)
      titleText = userContent .find \.mbs .text!
      linkHref = userContent .find \a .attr \href
      censorFacebookNode userContent, titleText, linkHref


  buildActionBar = (options) ->
    url = "http://newshelper.g0v.tw"
    url += "?news_link=" + encodeURIComponent(options.link) + "&news_title= " + encodeURIComponent(options.title)  if "undefined" isnt typeof (options.title) and "undefined" isnt typeof (options.link)
    "<a href=\"" + url + "\" target=\"_blank\">回報給新聞小幫手</a>"

  registerObserver = ->
    MutationObserver = window.MutationObserver or window.WebKitMutationObserver
    mutationObserverConfig =
      target: document.getElementsByTagName(\body)[0]
      config:
        attributes: true
        childList: true
        characterData: true

    throttle = do ->
      var timer_
      (fn, wait) ->
        if timer_ then clearTimeout timer_
        timer_ := setTimeout fn, wait

    mutationObserver = new MutationObserver (mutations) ->
      # So far, the value of mutation.target is always document.body.
      # Unless we want to do more fine-granted control, it is ok to pass document.body for now.
      throttle ->
        censorFacebook document.body
      , 1000

    mutationObserver.observe mutationObserverConfig.target, mutationObserverConfig.config

  do ->
    # check callback
    self.port.on \checkReportResult , (report) ->
      containerNodes[report.linkHref]?.nodes?.forEach (containerNode) ->
        if containerNode.hasClass className
          return false
        containerNode.addClass className
        containerNode.append buildWarningMessage(
          title: report.report_title
          link: report.report_link
        )

    censorFacebook document.body

    # deal with changed DOMs (i.e. AJAX-loaded content)
    registerObserver()

