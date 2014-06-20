class RankingPhrase < ActiveRecord::Base

def self.importance(bill)
    imp = 2
	RankingPhrase.find(:all).each do |r|
	if (!r.exception and !r.regex and bill.title.downcase.include?(r.phrase.downcase)) then imp = 1 end
    if (r.exception and !r.regex and imp == 1 and bill.title.downcase.include?(r.phrase.downcase)) then imp = 2 end
    if (r.exception and r.regex and imp == 1 and bill.title.downcase =~ Regexp.new(r.phrase)) then imp = 2 end
	end
	imp
end

end
