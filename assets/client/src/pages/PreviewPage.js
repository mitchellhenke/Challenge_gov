import React, { useEffect, useState } from 'react'
import axios from 'axios'
import queryString from 'query-string'
import { useParams, useLocation } from "react-router-dom";
import { ChallengeTile } from "../components/ChallengeTile"
import { ChallengeDetails } from '../components/ChallengeDetails';
import { PreviewBanner } from '../components/PreviewBanner';

export const PreviewPage = () => {
  const [currentChallenge, setCurrentChallenge] = useState()
  const [loadingState, setLoadingState] = useState(false)

  let { challengeId } = useParams()
  let query = useLocation().search

  const { print } = queryString.parse(query)

  const base_url = window.location.origin

  useEffect(() => {
    let challengeApiPath = base_url + `/api/challenges/preview/${challengeId}`

    setLoadingState(true)
    axios
      .get(challengeApiPath)
      .then(res => {
        setCurrentChallenge(res.data)
        setLoadingState(false)
      })
      .catch(e => {
        setLoadingState(false)
        console.log({e})
      })
  }, [])

  return (
    <div className="challenge-preview py-5">
      <div className="challenge-preview__top row mb-5">
        <div className="col-md-4">
          <ChallengeTile challenge={currentChallenge} preview={true} loading={loadingState}/>
        </div>
        <div className="col-md-8">
          <PreviewBanner challenge={currentChallenge} print={print} />
        </div>
      </div>
      <div className="row">
        <div className="col">
          <ChallengeDetails challenge={currentChallenge} preview={true} loading={loadingState} print={print} />
        </div>
      </div>
    </div>
  )
}