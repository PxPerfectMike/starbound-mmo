-- Starbound MMO Market UI
-- Simple static version for testing

function init()
  sb.logInfo("[MMO Market] UI initialized - static version")
end

function update(dt)
  -- Nothing to update in static version
end

function onBuy1()
  sb.logInfo("[MMO Market] Buy clicked: Refined Aegisalt")
  widget.setText("statusLabel", "^green;Bought Aegisalt!^reset;")
end

function onBuy2()
  sb.logInfo("[MMO Market] Buy clicked: Diamond")
  widget.setText("statusLabel", "^green;Bought Diamond!^reset;")
end

function onBuy3()
  sb.logInfo("[MMO Market] Buy clicked: Titanium Bar")
  widget.setText("statusLabel", "^green;Bought Titanium!^reset;")
end

function onBuy4()
  sb.logInfo("[MMO Market] Buy clicked: Solarium Star")
  widget.setText("statusLabel", "^green;Bought Solarium!^reset;")
end
